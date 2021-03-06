/**
 * \file
 * \brief     Memory mapping.
 * \author    Chris Smeele
 * \copyright Copyright (c) 2015, Chris Smeele. All rights reserved.
 * \license   MIT. See LICENSE for the full license text.
 */
#include "memmap.h"
#include "console.h"

MemMap memMap;

bool isMemAvailable(uint64_t start, uint64_t length) {
	assert(start + length > start);

	for (uint32_t i=0; i<memMap.regionCount; i++) {
		MemMapRegion region = memMap.regions[i];
		if (
			   region.start <= start
			&& region.start + region.length >= start + length
			&& region.type == MEMORY_REGION_TYPE_FREE
		) {
			// Only return true if a single free mem-map entry exist that covers
			// the entire queried region.
			return true;
			// This assumes no overlapping entries exist.
		}
	}
	return false;
}

int makeMemMap() {
	memset(&memMap, 0, sizeof(MemMap));
	uint32_t contVal = 0;

	for (uint32_t i=0; i<MEMMAP_MAX_REGIONS; i++) {
		do {
			uint32_t success = 0x0000e820;
			asm volatile (
				"int $0x15\n"
				"jnc .no_e820_error\n"
				"xor %%eax, %%eax\n"
				".no_e820_error:\n"
				: "+b" (contVal),
				  "+a" (success)
				: "c" (0x00000020), // Buffer size.
				  "d" (0x534d4150), // "SMAP".
				  "D" (&memMap.regions[i].start)
				: "cc", "memory"
			);

			if (!success)
				return 1;

			// Skip zero-length entries.
		} while (!memMap.regions[i].length);

		memMap.regions[i]._size = 20;
		memMap.regionCount++;

		if (contVal == 0)
			// Indicates end of list.
			return 0;
	}

	printf("warning: Memory map truncated.\n");
	return 0;
}
