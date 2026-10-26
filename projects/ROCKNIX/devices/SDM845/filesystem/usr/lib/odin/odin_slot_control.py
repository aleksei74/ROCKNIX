"""Inspect boot partitions and A/B slot state on supported AYN Odin devices."""
import hashlib
import json
from pathlib import Path
import re
import stat
import struct
import zlib

PARTLABEL = Path('/dev/disk/by-partlabel')
BOOTCTL = '/usr/bin/qbootctl'
SWAPPED = ('abl', 'aop', 'apdp', 'cmnlib', 'cmnlib64', 'devcfg', 'dtbo',
           'hyp', 'keymaster', 'msadp', 'qupfw', 'storsec', 'tz', 'vbmeta',
           'vbmeta_system', 'boot', 'system', 'vendor', 'modem', 'system_ext', 'product')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def partition(name):
    path = (PARTLABEL / name).resolve(strict=True)
    require(stat.S_ISBLK(path.stat().st_mode) and re.fullmatch(r'sd[a-z]\d+', path.name),
            'Expected an internal UFS partition: ' + name)
    node = Path('/sys/class/block') / path.name
    disk = re.sub(r'\d+$', '', path.name)
    require((node / 'partition').is_file() and
            (Path('/sys/class/block') / disk / 'removable').read_text().strip() == '0',
            'Unexpected storage for ' + name)
    host = (Path('/sys/class/block') / disk / 'device').resolve()
    require('1d84000' in str(host), 'Partition is not on the Odin UFS controller')
    return path, Path('/dev') / disk


def classify_boot(data, carriers):
    require(len(data) >= 4096 and data[:8] == b'ANDROID!', 'Unknown boot image header')
    for image in carriers:
        size = image['bytes']
        if len(data) >= size and hashlib.sha256(data[:size]).hexdigest() == image['sha256']:
            return 'rocknix'
    kernel, _, ramdisk = struct.unpack_from('<III', data, 8)
    page, version = struct.unpack_from('<II', data, 36)
    require(version <= 2 and page == 4096 and kernel > 0 and ramdisk > 0 and
            page + ((kernel + page - 1) // page) * page + ramdisk <= 67108864,
            'Boot image is neither a supported ROCKNIX carrier nor Android')
    return 'android'


def read_boot(path, carriers):
    with path.open('rb') as stream:
        return stream.read(max(4096, max(row['bytes'] for row in carriers)))


def choose_android(images):
    require(sorted(images.values()) == ['android', 'rocknix'],
            'Expected exactly one Android slot and one ROCKNIX slot')
    return next(slot for slot, kind in images.items() if kind == 'android')


def read_gpt(disk):
    node = Path('/sys/class/block') / disk.name
    sector = int((node / 'queue/logical_block_size').read_text())
    total = int((node / 'size').read_text()) * 512 // sector
    require(sector in (512, 4096) and total > 8, 'Invalid UFS geometry')
    with disk.open('rb') as stream:
        def table(lba):
            stream.seek(lba * sector)
            header = stream.read(sector)
            require(header[:8] == b'EFI PART', 'Missing GPT signature: ' + str(disk))
            length, crc = struct.unpack_from('<II', header, 12)
            require(92 <= length <= sector, 'Invalid GPT header size')
            checked = bytearray(header[:length]); checked[16:20] = b'\0' * 4
            require(zlib.crc32(checked) == crc, 'GPT header CRC mismatch')
            current, other, first, last = struct.unpack_from('<QQQQ', header, 24)
            start, count, size, array_crc = struct.unpack_from('<QIII', header, 72)
            require(current == lba and other in (1, total - 1) and other != current and
                    2 <= first <= last < total - 1 and 1 <= count <= 4096 and size == 128 and
                    start < total and start * sector + count * size <= total * sector,
                    'Unsupported GPT layout')
            end = start + (count * size + sector - 1) // sector
            require((lba == 1 and 2 <= start < end <= first) or
                    (lba == total - 1 and last < start < end <= total - 1),
                    'GPT table overlaps usable partitions')
            stream.seek(start * sector); entries = stream.read(count * size)
            require(len(entries) == count * size and zlib.crc32(entries) == array_crc,
                    'GPT partition CRC mismatch')
            return header, entries, first, last
        primary = table(1); backup = table(total - 1)
        require(primary[1:] == backup[1:] and primary[0][56:72] == backup[0][56:72],
                'GPT copies disagree')
        names = {}
        for offset in range(0, len(primary[1]), 128):
            entry = primary[1][offset:offset + 128]
            if entry[:16] != b'\0' * 16:
                name = entry[56:128].decode('utf-16-le').rstrip('\0')
                require(name not in names, 'Duplicate GPT partition name')
                names[name] = entry
        front_size = primary[2] * sector
        tail_size = (total - primary[3] - 1) * sector
        require(front_size <= 2 ** 20 and tail_size <= 2 ** 20, 'Unexpected GPT region size')
        stream.seek(0); front = stream.read(front_size)
        stream.seek((primary[3] + 1) * sector); tail = stream.read(tail_size)
    return {'sector': sector, 'tail_offset': (primary[3] + 1) * sector,
            'front': front, 'tail': tail, 'entries': names}


def active_slot(tables):
    entries = next(t['entries'] for t in tables.values() if 'boot_a' in t['entries'])
    active = [slot for slot in 'ab' if entries['boot_' + slot][54] & 4]
    require(len(active) == 1, 'Boot slot flags are ambiguous')
    return active[0]


def inspect():
    model = Path('/proc/device-tree/model').read_bytes().rstrip(b'\0').decode()
    require(model in ('AYN Odin', 'AYN Odin M2'), 'This action supports SDM845 Odin only')
    manifest = json.loads(Path('/usr/share/odin/slot-carriers.json').read_text())
    carriers = [row for row in manifest['variants'].values() if row['dtb_model'] == model]
    require(carriers, 'No supported boot carrier for this Odin model')
    paths = {}; disks = set()
    for base in (*SWAPPED, 'xbl'):
        present = [(PARTLABEL / (base + '_' + slot)).exists() for slot in 'ab']
        require(present[0] == present[1], 'Incomplete A/B partition pair: ' + base)
        require(base not in ('boot', 'dtbo', 'abl', 'xbl') or all(present),
                'Missing required partition pair: ' + base)
        if all(present):
            for slot in 'ab':
                path, disk = partition(base + '_' + slot)
                paths[base + '_' + slot] = path; disks.add(disk)
    require(partition('boot_a')[1] == partition('boot_b')[1], 'Boot partitions span UFS LUNs')
    tables = {disk: read_gpt(disk) for disk in disks}
    images = {slot: classify_boot(read_boot(paths['boot_' + slot], carriers), carriers)
              for slot in 'ab'}
    target = choose_android(images)
    active = active_slot(tables)
    for name in paths:
        if name.startswith('xbl_'):
            continue
        entry = next((table['entries'][name] for table in tables.values()
                      if name in table['entries']), None)
        require(entry is not None and bool(entry[54] & 4) == (name[-1] == active),
                'Inconsistent active-slot flags: ' + name)
    lun_paths = list(Path('/sys/bus/platform/devices').glob('1d84000.*/attributes/boot_lun_enabled'))
    require(len(lun_paths) == 1, 'Cannot read the UFS boot LUN')
    lun = int(lun_paths[0].read_text().strip(), 0)
    require(lun in (1, 2) and lun == 'ab'.index(active) + 1, 'UFS boot LUN disagrees with GPT')
    require(Path('/dev/bsg/ufs-bsg0').exists(), 'UFS boot-control interface is missing')
    return target, tables, paths, carriers, lun_paths[0]
