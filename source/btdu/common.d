/*
 * Copyright (C) 2020, 2021, 2022  Vladimir Panteleev <btdu@cy.md>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License v2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 021110-1307, USA.
 */

/// Common definitions
module btdu.common;

import std.format : format;
import std.random : Random;

enum btduVersion = "0.3.1";

alias Seed = typeof(Random.defaultSeed);

// C error messages

struct Errno
{
	string name, description;
}
int[string] errnoLookup;
ref Errno getErrno(int errno)
{
	static Errno[int] cache;
	return cache.require(errno, {
		Errno m;

		// TODO: use strerrorname_np, once glibc 2.32 is generally available everywhere
		switch (errno)
		{
			case 1: m.name = "EPERM"; break;
			case 2: m.name = "ENOENT"; break;
			case 3: m.name = "ESRCH"; break;
			case 4: m.name = "EINTR"; break;
			case 5: m.name = "EIO"; break;
			case 6: m.name = "ENXIO"; break;
			case 7: m.name = "E2BIG"; break;
			case 8: m.name = "ENOEXEC"; break;
			case 9: m.name = "EBADF"; break;
			case 10: m.name = "ECHILD"; break;
			case 11: m.name = "EAGAIN"; break;
			case 12: m.name = "ENOMEM"; break;
			case 13: m.name = "EACCES"; break;
			case 14: m.name = "EFAULT"; break;
			case 15: m.name = "ENOTBLK"; break;
			case 16: m.name = "EBUSY"; break;
			case 17: m.name = "EEXIST"; break;
			case 18: m.name = "EXDEV"; break;
			case 19: m.name = "ENODEV"; break;
			case 20: m.name = "ENOTDIR"; break;
			case 21: m.name = "EISDIR"; break;
			case 22: m.name = "EINVAL"; break;
			case 23: m.name = "ENFILE"; break;
			case 24: m.name = "EMFILE"; break;
			case 25: m.name = "ENOTTY"; break;
			case 26: m.name = "ETXTBSY"; break;
			case 27: m.name = "EFBIG"; break;
			case 28: m.name = "ENOSPC"; break;
			case 29: m.name = "ESPIPE"; break;
			case 30: m.name = "EROFS"; break;
			case 31: m.name = "EMLINK"; break;
			case 32: m.name = "EPIPE"; break;
			case 33: m.name = "EDOM"; break;
			case 34: m.name = "ERANGE"; break;
			case 35: m.name = "EDEADLK"; break;
			case 36: m.name = "ENAMETOOLONG"; break;
			case 37: m.name = "ENOLCK"; break;
			case 38: m.name = "ENOSYS"; break;
			case 39: m.name = "ENOTEMPTY"; break;
			case 40: m.name = "ELOOP"; break;
			case 42: m.name = "ENOMSG"; break;
			case 43: m.name = "EIDRM"; break;
			case 44: m.name = "ECHRNG"; break;
			case 45: m.name = "EL2NSYNC"; break;
			case 46: m.name = "EL3HLT"; break;
			case 47: m.name = "EL3RST"; break;
			case 48: m.name = "ELNRNG"; break;
			case 49: m.name = "EUNATCH"; break;
			case 50: m.name = "ENOCSI"; break;
			case 51: m.name = "EL2HLT"; break;
			case 52: m.name = "EBADE"; break;
			case 53: m.name = "EBADR"; break;
			case 54: m.name = "EXFULL"; break;
			case 55: m.name = "ENOANO"; break;
			case 56: m.name = "EBADRQC"; break;
			case 57: m.name = "EBADSLT"; break;
			case 59: m.name = "EBFONT"; break;
			case 60: m.name = "ENOSTR"; break;
			case 61: m.name = "ENODATA"; break;
			case 62: m.name = "ETIME"; break;
			case 63: m.name = "ENOSR"; break;
			case 64: m.name = "ENONET"; break;
			case 65: m.name = "ENOPKG"; break;
			case 66: m.name = "EREMOTE"; break;
			case 67: m.name = "ENOLINK"; break;
			case 68: m.name = "EADV"; break;
			case 69: m.name = "ESRMNT"; break;
			case 70: m.name = "ECOMM"; break;
			case 71: m.name = "EPROTO"; break;
			case 72: m.name = "EMULTIHOP"; break;
			case 73: m.name = "EDOTDOT"; break;
			case 74: m.name = "EBADMSG"; break;
			case 75: m.name = "EOVERFLOW"; break;
			case 76: m.name = "ENOTUNIQ"; break;
			case 77: m.name = "EBADFD"; break;
			case 78: m.name = "EREMCHG"; break;
			case 79: m.name = "ELIBACC"; break;
			case 80: m.name = "ELIBBAD"; break;
			case 81: m.name = "ELIBSCN"; break;
			case 82: m.name = "ELIBMAX"; break;
			case 83: m.name = "ELIBEXEC"; break;
			case 84: m.name = "EILSEQ"; break;
			case 85: m.name = "ERESTART"; break;
			case 86: m.name = "ESTRPIPE"; break;
			case 87: m.name = "EUSERS"; break;
			case 88: m.name = "ENOTSOCK"; break;
			case 89: m.name = "EDESTADDRREQ"; break;
			case 90: m.name = "EMSGSIZE"; break;
			case 91: m.name = "EPROTOTYPE"; break;
			case 92: m.name = "ENOPROTOOPT"; break;
			case 93: m.name = "EPROTONOSUPPORT"; break;
			case 94: m.name = "ESOCKTNOSUPPORT"; break;
			case 95: m.name = "EOPNOTSUPP"; break;
			case 96: m.name = "EPFNOSUPPORT"; break;
			case 97: m.name = "EAFNOSUPPORT"; break;
			case 98: m.name = "EADDRINUSE"; break;
			case 99: m.name = "EADDRNOTAVAIL"; break;
			case 100: m.name = "ENETDOWN"; break;
			case 101: m.name = "ENETUNREACH"; break;
			case 102: m.name = "ENETRESET"; break;
			case 103: m.name = "ECONNABORTED"; break;
			case 104: m.name = "ECONNRESET"; break;
			case 105: m.name = "ENOBUFS"; break;
			case 106: m.name = "EISCONN"; break;
			case 107: m.name = "ENOTCONN"; break;
			case 108: m.name = "ESHUTDOWN"; break;
			case 109: m.name = "ETOOMANYREFS"; break;
			case 110: m.name = "ETIMEDOUT"; break;
			case 111: m.name = "ECONNREFUSED"; break;
			case 112: m.name = "EHOSTDOWN"; break;
			case 113: m.name = "EHOSTUNREACH"; break;
			case 114: m.name = "EALREADY"; break;
			case 115: m.name = "EINPROGRESS"; break;
			case 116: m.name = "ESTALE"; break;
			case 117: m.name = "EUCLEAN"; break;
			case 118: m.name = "ENOTNAM"; break;
			case 119: m.name = "ENAVAIL"; break;
			case 120: m.name = "EISNAM"; break;
			case 121: m.name = "EREMOTEIO"; break;
			case 122: m.name = "EDQUOT"; break;
			case 123: m.name = "ENOMEDIUM"; break;
			case 124: m.name = "EMEDIUMTYPE"; break;
			case 125: m.name = "ECANCELED"; break;
			case 126: m.name = "ENOKEY"; break;
			case 127: m.name = "EKEYEXPIRED"; break;
			case 128: m.name = "EKEYREVOKED"; break;
			case 129: m.name = "EKEYREJECTED"; break;
			case 130: m.name = "EOWNERDEAD"; break;
			case 131: m.name = "ENOTRECOVERABLE"; break;
			case 132: m.name = "ERFKILL"; break;
			case 133: m.name = "EHWPOISON"; break;
			default: m.name = format!"%d"(errno);
		}
		errnoLookup.require(m.name, errno);

		import core.stdc.string : strlen, strerror_r;
		char[1024] buf = void;
		auto s = strerror_r(errno, buf.ptr, buf.length);
		m.description = s[0 .. s.strlen].idup;

		return m;
	}());
}
