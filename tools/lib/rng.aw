# tools/lib/rng.aw -- random numbers for the tools: splitmix64, the same
# numbers for the same seed on every run and machine.
#
# The state is 8 bytes that the caller owns; the functions take their
# address. rngseed stores the seed there. Each number comes from the
# state plus 0x9e3779b97f4a7c15, kept as the new state, as
#   z = (z ^ z>>30) * 0xbf58476d1ce4e5b9
#   z = (z ^ z>>27) * 0x94d049bb133111eb
#   z ^ z>>31
# with 64-bit wrapping.
#
# Every name of this file starts with "rng"; a program has no var of such
# a name (see lib/std/io.aw).

fn rngseed rngs rngv
	store rngs rngv
end

# the next 64-bit number
fn rngnext rngs
	load rngs as rngz
	rngz+=0x9e3779b97f4a7c15
	store rngs rngz
	rngz=(rngz^rngz>>30)*0xbf58476d1ce4e5b9
	rngz=(rngz^rngz>>27)*0x94d049bb133111eb
	ret rngz^rngz>>31
end

# a number from 0 to rngn-1, each as likely as the others: the next
# number that is not below 2^64 mod rngn, modulo rngn. rngn is not 0.
fn rngbelow rngs rngn
	rngt=(0-rngn)%rngn
	label again
	call rngnext rngs as rngz
	jlt rngz rngt again
	ret rngz%rngn
end

# put the rngn numbers of 8 bytes at rnga in a random order, every order
# as likely as the others: from the last place down, each place changes
# its number with that of a place not above it (Fisher and Yates)
fn rngshuffle rngs rnga rngn
	while rngn>1
		call rngbelow rngs rngn as rngj
		rngn-=1
		load rnga+rngn*8 as rngx
		load rnga+rngj*8 as rngy
		store rnga+rngn*8 rngy
		store rnga+rngj*8 rngx
	end
end
