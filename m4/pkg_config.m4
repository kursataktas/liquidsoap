dnl Taken an modified from:
dnl pkg.m4 - Macros to locate and utilise pkg-config.            -*- Autoconf -*-
dnl 
dnl Copyright © 2004 Scott James Remnant <scott@netsplit.com>.
dnl
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program; if not, write to the Free Software
dnl Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
dnl
dnl As a special exception to the GNU General Public License, if you
dnl distribute this file as part of a program that contains a
dnl configuration script generated by Autoconf, you may include it under
dnl the same distribution terms that you use for the rest of that program.

dnl PKG_PROG_PKG_CONFIG([MIN-VERSION])
dnl ----------------------------------
AC_DEFUN([PKG_PROG_PKG_CONFIG],
[m4_pattern_forbid([^_?PKG_[A-Z_]+$])
m4_pattern_allow([^PKG_CONFIG(_PATH)?$])
AC_ARG_VAR([PKG_CONFIG], [path to pkg-config utility])dnl
if test "x$ac_cv_env_PKG_CONFIG_set" != "xset"; then
  AC_PATH_TOOL([PKG_CONFIG], [pkg-config])
fi
if test -n "$PKG_CONFIG"; then
  _pkg_min_version=m4_default([$1], [0.9.0])
  AC_MSG_CHECKING([pkg-config is at least version $_pkg_min_version])
  if $PKG_CONFIG --atleast-pkgconfig-version $_pkg_min_version; then
    AC_MSG_RESULT([yes])
  else
    AC_MSG_ERROR([no])
    PKG_CONFIG=""
  fi
    
fi[]dnl
])dnl PKG_PROG_PKG_CONFIG

AC_ARG_VAR([PKG_CONFIG_OPTIONS], [Additional options passed when invoking pkg-config])

dnl PKG_CONFIG_CHECK_MODULE([name],[min-version])
dnl min-version is optional
AC_DEFUN([PKG_CONFIG_CHECK_MODULE],
[if test -n "$2"; then
  PKGCONFIG_CHECK_VERSION=" >= $2"
else
  PKGCONFIG_CHECK_VERSION=""
fi
AC_MSG_CHECKING([whether pkg-config knows about $1${PKGCONFIG_CHECK_VERSION}])
if ! $PKG_CONFIG $PKG_CONFIG_OPTIONS --exists $1; then
  AC_MSG_ERROR([$1.pc not found.. Do you need to set PKG_CONFIG_PATH?])
else
  if test -n "$2"; then
    if ! $PKG_CONFIG $PKG_CONFIG_OPTIONS --atleast-version=$2 $1; then
      $1_VERSION="`$PKG_CONFIG $PKG_CONFIG_OPTIONS --modversion $1`"
      AC_MSG_ERROR([requires version >= $2, found ${$1_VERSION}])
    else
      AC_MSG_RESULT([ok])
    fi
  else
    AC_MSG_RESULT([ok])
  fi
fi
CFLAGS="$CFLAGS `$PKG_CONFIG $PKG_CONFIG_OPTIONS --cflags $1`"
CPPFLAGS="$CPPFLAGS `$PKG_CONFIG $PKG_CONFIG_OPTIONS --cflags $1`"
LIBS="$LIBS `$PKG_CONFIG $PKG_CONFIG_OPTIONS --libs-only-l $1`"
LDFLAGS="$LDFLAGS `$PKG_CONFIG $PKG_CONFIG_OPTIONS --libs-only-L $1`"
])
