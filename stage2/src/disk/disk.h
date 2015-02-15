/**
 * \file
 * \brief     Disk I/O.
 * \author    Chris Smeele
 * \copyright Copyright (c) 2015, Chris Smeele. All rights reserved.
 * \license   MIT. See LICENSE for the full license text.
 */
#ifndef _DISK_DISK_H
#define _DISK_DISK_H

#include "common.h"

#define DISK_MAX_DISKS               8
#define DISK_MAX_PARTITIONS_PER_DISK 16
#define DISK_MAX_BLOCK_SIZE          4096

#define DISK_PART_SCAN_OK             (0)
#define DISK_PART_SCAN_ERR_TRY_OTHER (-1)
#define DISK_PART_SCAN_ERR_CORRUPT   (-2)
#define DISK_PART_SCAN_ERR_IO        (-3)

typedef struct Disk Disk; // Allows referring to Disk in the Partition struct.

/**
 * \brief Disk partition.
 */
typedef struct {
	Disk *disk;
	uint16_t partitionNo;
	uint8_t  systemId;
	uint64_t lbaStart;
	uint64_t blockCount;
} Partition;

/**
 * \brief Hard disk.
 */
struct Disk {
	bool     available; ///< Whether we can read from this disk.
	uint16_t diskNo;    ///< 0, 1 ...
	uint8_t  biosId;    ///< 80h, 81h, ... (used for int13h).
	uint16_t blockSize; ///< Usually 512, may be 4096.
	uint64_t blockCount;
	uint16_t partitionCount;
	Partition partitions[DISK_MAX_PARTITIONS_PER_DISK];
};

extern uint32_t diskCount;
extern Disk     disks[];

/**
 * \brief Get a pointer to the Disk structure for the boot disk.
 *
 * \return
 */
Disk *getBootDisk();

/**
 * \brief Read sectors from a hard drive.
 *
 * \param disk a pointer to a disk structure
 * \param lba logical block address
 * \param dest destination address
 * \param blockCount amount of blocks to read
 *
 * \return zero on success, non-zero on error
 */
int diskRead(Disk *disk, uint64_t lba, uint64_t dest, uint64_t blockCount);

/**
 * \brief Detects disk drives, parses partition tables, fills Disk structs.
 *
 * \return the amount of available disk drives (disks we can read from)
 */
int disksDiscover();

#endif /* _DISK_DISK_H */