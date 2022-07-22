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

/// Sampling subprocess implementation
module btdu.sample;

import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;

import std.algorithm.iteration;
import std.algorithm.searching : countUntil;
import std.bigint;
import std.conv : to;
import std.datetime.stopwatch;
import std.exception;
import std.random;
import std.string;

import ae.sys.shutdown;
import ae.utils.aa : addNew;
import ae.utils.appender;
import ae.utils.meta : I;
import ae.utils.time : stdTime;

import btrfs;
import btrfs.c.ioctl : btrfs_ioctl_dev_info_args;
import btrfs.c.kerncompat;
import btrfs.c.kernel_shared.ctree;

import btdu.proto;

void subprocessMain(string fsPath, bool physical)
{
	try
	{
		// Ignore SIGINT/SIGTERM, because the main process will handle it for us.
		// We want the main process to receive and process the signal before any child
		// processes do, otherwise the main process doesn't know if the child exited due to an
		// abrupt failure or simply because it received and processed the signal before it did.
		addShutdownHandler((reason) {});

		// stderr.writeln("Opening filesystem...");
		int fd = open(fsPath.toStringz, O_RDONLY);
		errnoEnforce(fd >= 0, "open");

		// stderr.writeln("Reading chunks...");

		/// Used for logicalOffset to represent unallocated space in physical mode.
		enum u64 hole = -1;

		/// Represents one continuous sampling zone,
		/// in physical or logical space (depending on the mode).
		/// Represents one physical extent or one logical chunk.
		static struct ChunkInfo
		{
			u64 type;
			u64 logicalOffset, logicalLength;
			u64 devID;
			u64 physicalOffset, physicalLength;
			u64 numStripes, stripeIndex, stripeLength;
		}
		@property u64 length(ChunkInfo c) { return physical ? c.physicalLength : c.logicalLength; }

		ChunkInfo[] chunks;
		btrfs_ioctl_dev_info_args[] devices;

		if (!physical) // logical mode
		{
			enumerateChunks(fd, (u64 offset, const ref btrfs_chunk chunk) {
				chunks ~= ChunkInfo(
					chunk.type,
					offset, chunk.length,
					-1,
					-1, 0,
				);
			});
		}
		else // physical mode
		{
			btrfs_chunk[u64] chunkLookup;
			btrfs_stripe[][u64] stripeLookup;
			enumerateChunks(fd, (u64 offset, const ref btrfs_chunk chunk) {
				chunkLookup.addNew(offset, cast()chunk).enforce("Chunk with duplicate offset");
				stripeLookup.addNew(offset, chunk.stripe.ptr[0 .. chunk.num_stripes].dup).enforce("Chunk with duplicate offset");
			});

			devices = getDevices(fd);

			foreach (ref device; devices)
			{
				u64 lastOffset = 0;
				void flushHole(u64 dataStart, u64 dataEnd)
				{
					if (dataStart != lastOffset)
					{
						enforce(lastOffset < dataStart, "Unordered extents");
						chunks ~= ChunkInfo(
							0,
							hole, 0,
							device.devid,
							lastOffset, dataStart - lastOffset,
						);
					}
					lastOffset = dataEnd;
				}
				enumerateDevExtents(fd, (u64 devid, u64 offset, const ref btrfs_dev_extent extent) {
					flushHole(offset, offset + extent.length);
					auto chunk = (extent.chunk_offset in chunkLookup).enforce("Chunk for extent not found");
					auto stripes = stripeLookup[extent.chunk_offset];
					auto stripeIndex = stripes.countUntil!((ref stripe) => stripe.devid == devid && stripe.offset == offset);
					enforce(stripeIndex >= 0, "Stripe for extent not found in chunk");

					chunks ~= ChunkInfo(
						chunk.type,
						offset, chunk.length,
						devid,
						extent.chunk_offset, extent.length,
						chunk.num_stripes, stripeIndex, chunk.stripe_len,
					);
				}, [device.devid, device.devid]);
				flushHole(device.total_bytes, device.total_bytes);
			}

			assert(chunks.map!((ref chunk) => chunk.I!length).sum == devices.map!((ref device) => device.total_bytes).sum);
		}

		u64 totalSize = chunks.map!((ref chunk) => chunk.I!length).sum;
		// stderr.writefln("Found %d chunks with a total size of %d.", chunks.length, totalSize);
		send(StartMessage(totalSize, devices));

		while (true)
		{
			auto targetPos = uniform(0, totalSize);
			u64 pos = 0;
			foreach (ref chunk; chunks)
			{
				auto end = pos + chunk.I!length;
				if (end > targetPos)
				{
					auto sw = StopWatch(AutoStart.yes);

					u64 logicalOffset, physicalOffset;
					if (!physical)
						logicalOffset = chunk.logicalOffset + (targetPos - pos);
					else
					{
						u64 physicalOffsetInExtent = (targetPos - pos);
						physicalOffset = chunk.physicalOffset + physicalOffsetInExtent;

						if (chunk.logicalOffset == hole)
						{
							logicalOffset = hole;
						}
						else
						{
							// This is an approximation.
							// The exact algorithm is rather complicated, see btrfs_map_block or btrfs_map_physical.c.
							// Because data is distributed uniformly anyway, the only reason why we would
							// want to use the full algorithm would be to provide accurate offsets.
							// For RAID5/6 the calculation would need to be partially meaningless anyway,
							// as the parity blocks don't correspond to any particular single logical offset.
							auto physicalStripeIndex = physicalOffsetInExtent / chunk.stripeLength;
							auto offsetInStripe = physicalOffsetInExtent % chunk.stripeLength;
							auto logicalStripeIndex = (BigInt(physicalStripeIndex) * chunk.logicalLength / chunk.physicalLength).to!ulong;
							logicalOffset = chunk.logicalOffset + logicalStripeIndex * chunk.stripeLength + offsetInStripe;
						}
					}

					send(ResultStartMessage(chunk.type, Offset(logicalOffset, chunk.devID, physicalOffset)));

					if (chunk.type & BTRFS_BLOCK_GROUP_DATA)
					{
						foreach (ignoringOffset; [false, true])
						{
							try
							{
								bool called;
								logicalIno(fd, logicalOffset,
									(u64 inode, u64 offset, u64 rootID)
									{
										called = true;

										// writeln("- ", inode, " ", offset, " ", root);
										cast(void) offset; // unused

										// Send new roots before the inode start
										cast(void)getRoot(fd, rootID);

										send(ResultInodeStartMessage(rootID));

										try
										{
											static FastAppender!char pathBuf;
											pathBuf.clear();
											pathBuf.put(fsPath);

											void putRoot(u64 rootID)
											{
												auto root = getRoot(fd, rootID);
												if (root is Root.init)
													enforce(rootID == BTRFS_FS_TREE_OBJECTID, "Unresolvable root");
												else
													putRoot(root.parent);
												if (root.path)
												{
													pathBuf.put('/');
													pathBuf.put(root.path);
												}
											}
											putRoot(rootID);
											pathBuf.put('\0');

											int rootFD = open(pathBuf.get().ptr, O_RDONLY);
											if (rootFD < 0)
											{
												send(ResultInodeErrorMessage(btdu.proto.Error("open", errno, pathBuf.get()[0 .. $-1])));
												return;
											}
											scope(exit) close(rootFD);

											inoPaths(rootFD, inode, (char[] fn) {
												send(ResultMessage(fn));
											});
											send(ResultInodeEndMessage());
										}
										catch (Exception e)
											send(ResultInodeErrorMessage(e.toError));
									},
									ignoringOffset,
								);
								if (!called && !ignoringOffset)
								{
									// Retry with BTRFS_LOGICAL_INO_ARGS_IGNORE_OFFSET
									send(ResultIgnoringOffsetMessage());
									continue;
								}
							}
							catch (Exception e)
								send(ResultErrorMessage(e.toError));
							break;
						}
					}
					send(ResultEndMessage(sw.peek.stdTime));
					break;
				}
				pos = end;
			}
		}
	}
	catch (Throwable e)
	{
		debug
			send(FatalErrorMessage(e.toString()));
		else
			send(FatalErrorMessage(e.msg));
	}
}

private:

struct Root
{
	u64 parent;
	string path;
}
Root[u64] roots;

/// Performs memoized resolution of the path for a btrfs root object.
Root getRoot(int fd, __u64 rootID)
{
	return roots.require(rootID, {
		Root result;
		findRootBackRef(
			fd,
			rootID,
			(
				__u64 parentRootID,
				__u64 dirID,
				__u64 sequence,
				char[] name,
			) {
				cast(void) sequence; // unused

				inoLookup(
					fd,
					parentRootID,
					dirID,
					(char[] dirPath)
					{
						if (result !is Root.init)
							throw new Exception("Multiple root locations");
						result.path = cast(string)(dirPath ~ name);
						result.parent = parentRootID;
					}
				);
			}
		);

		// Ensure parents are written first
		if (result !is Root.init)
			cast(void)getRoot(fd, result.parent);

		send(NewRootMessage(rootID, result.parent, result.path));

		return result;
	}());
}

btdu.proto.Error toError(Exception e)
{
	btdu.proto.Error error;
	error.msg = e.msg;
	if (auto ex = cast(ErrnoException) e)
	{
		// Convert to errno + string
		import core.stdc.string : strlen, strerror_r;
		char[1024] buf = void;
		auto s = strerror_r(errno, buf.ptr, buf.length);

		import std.range : chain;
		auto suffix = chain(" (".representation, s[0 .. s.strlen].representation, ")".representation);
		if (error.msg.endsWith(suffix))
		{
			error.msg = error.msg[0 .. $ - suffix.length];
			error.errno = ex.errno;
		}
		else
			debug assert(false, "Unexpected ErrnoException message: " ~ error.msg);
	}
	return error;
}
