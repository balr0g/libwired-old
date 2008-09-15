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

#include "config.h"

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>

#ifdef HAVE_OPENSSL_SHA_H
#include <openssl/rand.h>
#endif

#ifdef HAVE_PATHS_H
#include <paths.h>
#endif

#ifdef HAVE_MACHINE_PARAM_H
#include <machine/param.h>
#endif

#ifdef HAVE_EXECINFO_H
#include <execinfo.h>
#endif

#include <wired/wi-assert.h>
#include <wired/wi-base.h>
#include <wired/wi-log.h>
#include <wired/wi-runtime.h>
#include <wired/wi-private.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

wi_boolean_t wi_chdir(wi_string_t *path) {
	if(chdir(wi_string_cstring(path)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



#pragma mark -

void wi_switch_user(uid_t uid, gid_t gid) {
	struct passwd	*user;
	struct group	*group;
	uid_t			euid;
	gid_t			egid;
	
	if(wi_log_path) {
		if(chown(wi_string_cstring(wi_log_path), uid, gid) < 0) {
			wi_log_warn(WI_STR("Could not change owner of %@: %s"),
				wi_log_path, strerror(errno));
		}
	}
	
	if(gid != getegid()) {
		user = getpwuid(uid);
		
		if(user) {
			if(initgroups(user->pw_name, gid) < 0) {
				wi_log_warn(WI_STR("Could not set group privileges: %s"),
					strerror(errno));
			}
		}
			
		if(setgid(gid) < 0) {
			wi_log_warn(WI_STR("Could not drop group privileges: %s"),
				strerror(errno));
		}
	}

	if(uid != geteuid()) {
		if(setuid(uid) < 0) {
			wi_log_warn(WI_STR("Could not drop user privileges: %s"),
				strerror(errno));
		}
	}

	euid = geteuid();
	egid = getegid();
	user = getpwuid(euid);
	group = getgrgid(egid);
	
	if(user && group) {
		wi_log_info(WI_STR("Operating as user %s (%d), group %s (%d)"),
			user->pw_name, user->pw_uid, group->gr_name, group->gr_gid);
	} else {
		wi_log_info(WI_STR("Operating as user %d, group %d"),
			euid, egid);
	}
}



wi_string_t * wi_user_name(void) {
	wi_string_t		*user;
	struct passwd	*pwd;
	
	user = wi_getenv(WI_STR("USER"));
	
	if(user)
		return user;
	
	pwd = getpwuid(getuid());
	
	if(!pwd)
		return NULL;
	
	return wi_string_with_cstring(pwd->pw_name);
}



wi_string_t * wi_user_home(void) {
	wi_string_t		*home;
	struct passwd	*pwd;
	
	home = wi_getenv(WI_STR("HOME"));
	
	if(home)
		return home;
	
	pwd = getpwuid(getuid());
	
	if(!pwd)
		return NULL;
	
	return wi_string_with_cstring(pwd->pw_dir);
}



#pragma mark -

wi_uinteger_t wi_page_size(void) {
#if defined(HAVE_GETPAGESIZE)
	return getpagesize();
#elif defined(PAGESIZE)
	return PAGESIZE;
#elif defined(EXEC_PAGESIZE)
	return EXEC_PAGESIZE;
#elif defined(NBPG)
#ifdef CLSIZE
	return NBPG * CLSIZE
#else
	return NBPG;
#endif
#elif defined(NBPC)
	return NBPC;
#else
	return 4096;
#endif
}



#pragma mark -

void * wi_malloc(size_t size) {
	void		*pointer;
	
	pointer = calloc(1, size);
	
	if(pointer == NULL)
		wi_crash();

	return pointer;
}



void * wi_realloc(void *pointer, size_t size) {
	void		*newpointer;
	
	newpointer = realloc(pointer, size);
	
	if(newpointer == NULL)
		wi_crash();
	
	return newpointer;
}



void wi_free(void *pointer) {
	if(pointer)
		free(pointer);
}



#pragma mark -

wi_array_t * wi_backtrace(void) {
#ifdef HAVE_BACKTRACE
	wi_array_t		*array;
	void			*callstack[128];
	char			**symbols;
	int				i, frames;
	
	frames = backtrace(callstack, sizeof(callstack));
	symbols = backtrace_symbols(callstack, frames);
	array = wi_array_init_with_capacity(wi_array_alloc(), frames);
	
	for(i = 0; i < frames; i++)
		wi_array_add_data(array, wi_string_with_cstring(symbols[i]));
	
	free(symbols);
	
	return wi_autorelease(array);
#else
	return NULL;
#endif
}



#pragma mark -

wi_string_t * wi_getenv(wi_string_t *name) {
	char			*value;
	
	value = getenv(wi_string_cstring(name));
	
	if(!value)
		return NULL;
	
	return wi_string_with_cstring(value);
}



#pragma mark -

void wi_getopt_reset(void) {
#ifdef __GLIBC__
	optind = 0;
#else
	optind = 1;
#endif

#if HAVE_DECL_OPTRESET
	optreset = 1;
#endif
}
