/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
 *  All rights reserved.
 * 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WI_FS_H
#define WI_FS_H 1

#include <sys/param.h>
#include <wired/wi-base.h>
#include <wired/wi-file.h>
#include <wired/wi-runtime.h>

#define WI_PATH_SIZE				MAXPATHLEN


struct _wi_fs_stat {
	uint32_t						dev;
	uint64_t						ino;
	uint32_t						mode;
	uint32_t						nlink;
	uint32_t						uid;
	uint32_t						gid;
	uint32_t						rdev;
	uint32_t						atime;
	uint32_t						mtime;
	uint32_t						ctime;
	uint32_t						birthtime;
	uint64_t						size;
	uint64_t						blocks;
	uint32_t						blksize;
};
typedef struct _wi_fs_stat			wi_fs_stat_t;

struct _wi_fs_statfs {
	uint32_t						bsize;
	uint32_t						frsize;
	uint64_t						blocks;
	uint64_t						bfree;
	uint64_t						bavail;
	uint64_t						files;
	uint64_t						ffree;
	uint64_t						favail;
	uint32_t						fsid;
	uint64_t						flag;
	uint64_t						namemax;
};
typedef struct _wi_fs_statfs		wi_fs_statfs_t;


WI_EXPORT wi_string_t *				wi_fs_temporary_path_with_template(wi_string_t *);

WI_EXPORT wi_boolean_t				wi_fs_delete(wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_clear(wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_rename(wi_string_t *, wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_symlink(wi_string_t *, wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_copy(wi_string_t *, wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_stat(wi_string_t *, wi_fs_stat_t *);
WI_EXPORT wi_boolean_t				wi_fs_lstat(wi_string_t *, wi_fs_stat_t *);
WI_EXPORT wi_boolean_t				wi_fs_statfs(wi_string_t *, wi_fs_statfs_t *);
WI_EXPORT wi_boolean_t				wi_fs_exists(wi_string_t *, wi_boolean_t *);
WI_EXPORT wi_boolean_t				wi_fs_create_directory(wi_string_t *, uint32_t);
WI_EXPORT wi_boolean_t				wi_fs_set_mode(wi_string_t *, uint32_t);
WI_EXPORT wi_boolean_t				wi_fs_is_alias(wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_is_alias_cpath(const char *);
WI_EXPORT wi_boolean_t				wi_fs_is_invisible(wi_string_t *);
WI_EXPORT wi_boolean_t				wi_fs_is_invisible_cpath(const char *);
WI_EXPORT wi_boolean_t				wi_fs_set_finder_comment(wi_string_t *, wi_string_t *);
WI_EXPORT wi_string_t *				wi_fs_finder_comment(wi_string_t *);

WI_EXPORT wi_array_t *				wi_fs_directory_contents_at_path(wi_string_t *);
WI_EXPORT wi_string_t *				wi_fs_sha1(wi_string_t *, wi_file_offset_t);

#endif /* WI_FS_H */
