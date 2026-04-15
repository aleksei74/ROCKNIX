// SPDX-License-Identifier: GPL-2.0-only
/*
 * RTL8733BU WiFi/BT power control driver
 *
 * Controls the power enable GPIO of the RTL8733BU combo chip via rfkill.
 * Registers both RFKILL_TYPE_WLAN and RFKILL_TYPE_BLUETOOTH so the stack
 * (wifictl, bluetooth settings) can control WiFi and BT independently.  Power
 * is kept on if either WiFi or BT is unblocked; power is cut only when both
 * are blocked (maximum battery when both are off).  Uses the same GPIO as
 * the original vcc_wifi regulator (enable-active-low).
 *
 * Combo dependency: the RTL8733BU is a single USB device whose Bluetooth
 * function only works after the WiFi driver (8733bu) has loaded and
 * initialized the firmware/combo block.  When the BT rfkill is unblocked
 * we ensure 8733bu is loaded via request_module() even if the user has
 * WiFi disabled in the UI (WLAN rfkill stays soft-blocked — the radio is
 * off but the module is present so BT can function).
 *
 * After turning power on (and on resume), we wait 100 ms before returning so
 * the chip is stable before USB enumerates; this avoids "WiFi not connected
 * after resume" when the host enumerates before the module is ready (same
 * idea as Rockchip wlan-platdata power sequencing).
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/kmod.h>
#include <linux/module.h>
#include <linux/mod_devicetable.h>
#include <linux/platform_device.h>
#include <linux/pm.h>
#include <linux/rfkill.h>
#include <linux/workqueue.h>

#define RTL8733BU_POWER_STABLE_MS	100

static char *wifi_module = "8733bu";
module_param(wifi_module, charp, 0644);
MODULE_PARM_DESC(wifi_module, "WiFi driver module to load for combo BT (default: 8733bu)");

struct rtl8733bu_power {
	struct gpio_desc *enable_gpio;
	struct rfkill *rfkill_wlan;
	struct rfkill *rfkill_bt;
	bool wlan_blocked;
	bool bt_blocked;
	struct work_struct combo_work;
	struct device *dev;
};

static void rtl8733bu_power_update_gpio(struct rtl8733bu_power *power)
{
	bool on = !power->wlan_blocked || !power->bt_blocked;

	gpiod_set_value_cansleep(power->enable_gpio, on ? 1 : 0);

	if (on)
		msleep(RTL8733BU_POWER_STABLE_MS);
}

/*
 * Load the WiFi combo module from a work queue (request_module sleeps).
 * Called when BT is unblocked so the combo firmware path is alive.
 */
static void rtl8733bu_combo_work_fn(struct work_struct *work)
{
	struct rtl8733bu_power *power =
		container_of(work, struct rtl8733bu_power, combo_work);
	int ret;

	ret = request_module("%s", wifi_module);
	if (ret)
		dev_warn(power->dev,
			 "request_module(%s) returned %d (BT may not work)\n",
			 wifi_module, ret);
	else
		dev_info(power->dev,
			 "loaded combo WiFi module %s for BT\n", wifi_module);
}

static int rtl8733bu_power_set_block_wlan(void *data, bool blocked)
{
	struct rtl8733bu_power *power = data;

	power->wlan_blocked = blocked;
	rtl8733bu_power_update_gpio(power);
	return 0;
}

static int rtl8733bu_power_set_block_bt(void *data, bool blocked)
{
	struct rtl8733bu_power *power = data;

	power->bt_blocked = blocked;
	rtl8733bu_power_update_gpio(power);

	if (!blocked)
		schedule_work(&power->combo_work);

	return 0;
}

static const struct rfkill_ops rtl8733bu_power_rfkill_ops_wlan = {
	.set_block = rtl8733bu_power_set_block_wlan,
};

static const struct rfkill_ops rtl8733bu_power_rfkill_ops_bt = {
	.set_block = rtl8733bu_power_set_block_bt,
};

static int rtl8733bu_power_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct rtl8733bu_power *power;
	int ret;

	power = devm_kzalloc(dev, sizeof(*power), GFP_KERNEL);
	if (!power)
		return -ENOMEM;

	power->dev = dev;
	INIT_WORK(&power->combo_work, rtl8733bu_combo_work_fn);

	power->enable_gpio = devm_gpiod_get(dev, "enable", GPIOD_OUT_HIGH);
	if (IS_ERR(power->enable_gpio)) {
		ret = PTR_ERR(power->enable_gpio);
		dev_err(dev, "failed to get enable GPIO: %d\n", ret);
		return ret;
	}

	power->wlan_blocked = false;
	power->bt_blocked = false;
	rtl8733bu_power_update_gpio(power);

	power->rfkill_wlan = rfkill_alloc("rtl8733bu wifi", dev, RFKILL_TYPE_WLAN,
					  &rtl8733bu_power_rfkill_ops_wlan, power);
	if (!power->rfkill_wlan)
		return -ENOMEM;
	rfkill_set_states(power->rfkill_wlan, false, false);
	ret = rfkill_register(power->rfkill_wlan);
	if (ret) {
		dev_err(dev, "failed to register rfkill wlan: %d\n", ret);
		rfkill_destroy(power->rfkill_wlan);
		return ret;
	}

	power->rfkill_bt = rfkill_alloc("rtl8733bu bluetooth", dev, RFKILL_TYPE_BLUETOOTH,
					&rtl8733bu_power_rfkill_ops_bt, power);
	if (!power->rfkill_bt) {
		ret = -ENOMEM;
		goto err_unregister_wlan;
	}
	rfkill_set_states(power->rfkill_bt, false, false);
	ret = rfkill_register(power->rfkill_bt);
	if (ret) {
		dev_err(dev, "failed to register rfkill bt: %d\n", ret);
		rfkill_destroy(power->rfkill_bt);
		goto err_unregister_wlan;
	}

	platform_set_drvdata(pdev, power);
	dev_info(dev, "rtl8733bu-power: WiFi/BT rfkill (combo module: %s)\n",
		 wifi_module);
	return 0;

err_unregister_wlan:
	rfkill_unregister(power->rfkill_wlan);
	rfkill_destroy(power->rfkill_wlan);
	return ret;
}

static void rtl8733bu_power_remove(struct platform_device *pdev)
{
	struct rtl8733bu_power *power = platform_get_drvdata(pdev);

	if (!power)
		return;
	cancel_work_sync(&power->combo_work);
	if (power->rfkill_bt) {
		rfkill_unregister(power->rfkill_bt);
		rfkill_destroy(power->rfkill_bt);
	}
	if (power->rfkill_wlan) {
		rfkill_unregister(power->rfkill_wlan);
		rfkill_destroy(power->rfkill_wlan);
	}
}

static void rtl8733bu_power_shutdown(struct platform_device *pdev)
{
	struct rtl8733bu_power *power = platform_get_drvdata(pdev);

	if (!power)
		return;
	cancel_work_sync(&power->combo_work);
	gpiod_set_value_cansleep(power->enable_gpio, 0);
}

static int rtl8733bu_power_resume(struct device *dev)
{
	struct rtl8733bu_power *power = dev_get_drvdata(dev);

	if (!power)
		return 0;

	rtl8733bu_power_update_gpio(power);
	return 0;
}

static const struct dev_pm_ops rtl8733bu_power_pm_ops = {
	.resume = rtl8733bu_power_resume,
};

static const struct of_device_id rtl8733bu_power_of_match[] = {
	{ .compatible = "rockchip,rtl8733bu-power" },
	{ }
};
MODULE_DEVICE_TABLE(of, rtl8733bu_power_of_match);

static struct platform_driver rtl8733bu_power_driver = {
	.probe    = rtl8733bu_power_probe,
	.remove   = rtl8733bu_power_remove,
	.shutdown = rtl8733bu_power_shutdown,
	.driver   = {
		.name = "rtl8733bu-power",
		.of_match_table = rtl8733bu_power_of_match,
		.pm = pm_sleep_ptr(&rtl8733bu_power_pm_ops),
	},
};
module_platform_driver(rtl8733bu_power_driver);

MODULE_DESCRIPTION("RTL8733BU WiFi/BT power via rfkill; auto-loads combo WiFi module for BT");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("ROCKNIX");
