/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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

#ifndef WI_SQLITE3

int wi_sqlite3_dummy = 0;

#else

#include <wired/wi-lock.h>
#include <wired/wi-macros.h>
#include <wired/wi-null.h>
#include <wired/wi-number.h>
#include <wired/wi-private.h>
#include <wired/wi-runtime.h>
#include <wired/wi-sqlite3.h>
#include <wired/wi-string.h>

#include <stdarg.h>
#include <string.h>

#include <pthread.h>
#include <sqlite3.h>

struct _wi_sqlite3_database {
	wi_runtime_base_t					base;
	
	sqlite3								*database;
	
	wi_recursive_lock_t					*lock;
};


static void								_wi_sqlite3_database_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_sqlite3_database_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_sqlite3_database_runtime_class = {
	"wi_sqlite3_database_t",
	_wi_sqlite3_database_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


struct _wi_sqlite3_statement {
	wi_runtime_base_t					base;
	
	sqlite3_stmt						*statement;
};


static void								_wi_sqlite3_statement_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_sqlite3_statement_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_sqlite3_statement_runtime_class = {
	"wi_sqlite3_statement_t",
	_wi_sqlite3_statement_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wi_sqlite3_register(void) {
	_wi_sqlite3_database_runtime_id = wi_runtime_register_class(&_wi_sqlite3_database_runtime_class);
	_wi_sqlite3_statement_runtime_id = wi_runtime_register_class(&_wi_sqlite3_statement_runtime_class);
}



void wi_sqlite3_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_sqlite3_database_runtime_id(void) {
	return _wi_sqlite3_database_runtime_id;
}



#pragma mark -

wi_sqlite3_database_t * wi_sqlite3_open_database_with_path(wi_string_t *path) {
	wi_sqlite3_database_t		*database;
	
	database			= wi_autorelease(wi_runtime_create_instance(_wi_sqlite3_database_runtime_id, sizeof(wi_sqlite3_database_t)));
	database->lock		= wi_recursive_lock_init(wi_recursive_lock_alloc());
	
	if(sqlite3_open(wi_string_cstring(path), &database->database) != SQLITE_OK) {
		if(database->database) {
			wi_error_set_sqlite3_error(database->database);
			
			sqlite3_close(database->database);
			database->database = NULL;
		} else {
			wi_error_set_errno(ENOMEM);
		}
		
		database = NULL;
	}
	
	return database;
}



#pragma mark -

static void _wi_sqlite3_database_dealloc(wi_runtime_instance_t *instance) {
	wi_sqlite3_database_t	*database = instance;
	
	if(database->database)
		sqlite3_close(database->database);
	
	wi_release(database->lock);
}



#pragma mark -

wi_runtime_id_t wi_sqlite3_statement_runtime_id(void) {
	return _wi_sqlite3_statement_runtime_id;
}



#pragma mark -

wi_dictionary_t * wi_sqlite3_execute_statement(wi_sqlite3_database_t *database, wi_string_t *format, ...) {
	wi_sqlite3_statement_t		*statement;
	wi_dictionary_t				*results;
	wi_string_t					*string;
	va_list						ap;
	
	va_start(ap, format);
	string = wi_string_with_format_and_arguments(format, ap);
	va_end(ap);
	
	statement = wi_autorelease(wi_runtime_create_instance(_wi_sqlite3_statement_runtime_id, sizeof(wi_sqlite3_statement_t)));
	
	wi_recursive_lock_lock(database->lock);

#ifdef HAVE_SQLITE3_PREPARE_V2
	if(sqlite3_prepare_v2(database->database, wi_string_cstring(string), wi_string_length(string), &statement->statement, NULL) == SQLITE_OK) {
#else
	if(sqlite3_prepare(database->database, wi_string_cstring(string), wi_string_length(string), &statement->statement, NULL) == SQLITE_OK) {
#endif
		results = wi_sqlite3_fetch_statement_results(database, statement);
	} else {
		wi_error_set_sqlite3_error(database->database);
		
		results = NULL;
	}

	wi_recursive_lock_unlock(database->lock);
	
	return results;
}



wi_sqlite3_statement_t * wi_sqlite3_prepare_statement(wi_sqlite3_database_t *database, wi_string_t *format, ...) {
	wi_sqlite3_statement_t		*statement;
	wi_string_t					*string;
	va_list						ap;
	
	va_start(ap, format);
	string = wi_string_with_format_and_arguments(format, ap);
	va_end(ap);
	
	statement = wi_autorelease(wi_runtime_create_instance(_wi_sqlite3_statement_runtime_id, sizeof(wi_sqlite3_statement_t)));
	
	wi_recursive_lock_lock(database->lock);
	
#ifdef HAVE_SQLITE3_PREPARE_V2
	if(sqlite3_prepare_v2(database->database, wi_string_cstring(string), wi_string_length(string), &statement->statement, NULL) != SQLITE_OK) {
#else
	if(sqlite3_prepare(database->database, wi_string_cstring(string), wi_string_length(string), &statement->statement, NULL) != SQLITE_OK) {
#endif
		wi_error_set_sqlite3_error(database->database);
		
		statement = NULL;
	}
	
	wi_recursive_lock_unlock(database->lock);
	
	return statement;
}



wi_dictionary_t * wi_sqlite3_fetch_statement_results(wi_sqlite3_database_t *database, wi_sqlite3_statement_t *statement) {
	wi_mutable_dictionary_t		*results;
	wi_runtime_instance_t		*instance;
	int							i, count;
	
	wi_recursive_lock_lock(database->lock);
	
	switch(sqlite3_step(statement->statement)) {
		case SQLITE_DONE:
			results = wi_mutable_dictionary();
			break;
			
		case SQLITE_ROW:
			results			= wi_mutable_dictionary();
			count			= sqlite3_column_count(statement->statement);
			
			for(i = 0; i < count; i++) {
				switch(sqlite3_column_type(statement->statement, i)) {
					case SQLITE_INTEGER:
						instance = wi_number_with_int64(sqlite3_column_int64(statement->statement, i));
						break;
						
					case SQLITE_FLOAT:
						instance = wi_number_with_double(sqlite3_column_double(statement->statement, i));
						break;
						
					case SQLITE_TEXT:
						instance = wi_string_with_cstring((const char *) sqlite3_column_text(statement->statement, i));
						break;
						
					case SQLITE_BLOB:
						instance = NULL;
						break;
						
					case SQLITE_NULL:
						instance = wi_null();
						break;
					
					default:
						instance = NULL;
						break;
				}
				
				if(instance)
					wi_mutable_dictionary_set_data_for_key(results, instance, wi_string_with_cstring(sqlite3_column_name(statement->statement, i)));
			}
			break;
			
		default:
			wi_error_set_sqlite3_error(database);
			
			results = NULL;
			break;
	}
	
	wi_recursive_lock_unlock(database->lock);
	
	wi_runtime_make_immutable(results);
		
	return results;
}



#pragma mark -

static void _wi_sqlite3_statement_dealloc(wi_runtime_instance_t *instance) {
	wi_sqlite3_statement_t	*statement = instance;
	
	if(statement->statement)
		sqlite3_finalize(statement->statement);
}

#endif
