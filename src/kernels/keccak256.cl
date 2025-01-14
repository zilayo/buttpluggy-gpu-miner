/*
   Copyright 2018 Lip Wee Yeo Amano

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

/**
* Based on the following, with small tweaks and optimizations:
*
* https://github.com/lwYeo/SoliditySHA3Miner/blob/master/SoliditySHA3Miner/
*   Miner/Kernels/OpenCL/sha3KingKernel.cl
*
* Originally modified for openCL processing by lwYeo
*
* Original implementor: David Leon Gil
*
* License: CC0, attribution kindly requested. Blame taken too, but not
* liability.
*/

/******** Keccak-f[1600] (for finding efficient Ethereum addresses) ********/

#define OPENCL_PLATFORM_UNKNOWN 0
#define OPENCL_PLATFORM_AMD   2

#ifndef PLATFORM
# define PLATFORM       OPENCL_PLATFORM_UNKNOWN
#endif

#if PLATFORM == OPENCL_PLATFORM_AMD
# pragma OPENCL EXTENSION   cl_amd_media_ops : enable
#endif

typedef union _nonce_t
{
  ulong   uint64_t;
  uint    uint32_t[2];
  uchar   uint8_t[8];
} nonce_t;

#if PLATFORM == OPENCL_PLATFORM_AMD
static inline ulong rol(const ulong x, const uint s)
{
  uint2 output;
  uint2 x2 = as_uint2(x);

  output = (s > 32u) ? amd_bitalign((x2).yx, (x2).xy, 64u - s) : amd_bitalign((x2).xy, (x2).yx, 32u - s);
  return as_ulong(output);
}
#else
#define rol(x, s) (((x) << s) | ((x) >> (64u - s)))
#endif

#define rol1(x) rol(x, 1u)

#define theta_(m, n, o) \
t = b[m] ^ rol1(b[n]); \
a[o + 0] ^= t; \
a[o + 5] ^= t; \
a[o + 10] ^= t; \
a[o + 15] ^= t; \
a[o + 20] ^= t; \

#define theta() \
b[0] = a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20]; \
b[1] = a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21]; \
b[2] = a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22]; \
b[3] = a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23]; \
b[4] = a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24]; \
theta_(4, 1, 0); \
theta_(0, 2, 1); \
theta_(1, 3, 2); \
theta_(2, 4, 3); \
theta_(3, 0, 4);

#define rhoPi_(m, n) t = b[0]; b[0] = a[m]; a[m] = rol(t, n); \

#define rhoPi() t = a[1]; b[0] = a[10]; a[10] = rol1(t); \
rhoPi_(7, 3); \
rhoPi_(11, 6); \
rhoPi_(17, 10); \
rhoPi_(18, 15); \
rhoPi_(3, 21); \
rhoPi_(5, 28); \
rhoPi_(16, 36); \
rhoPi_(8, 45); \
rhoPi_(21, 55); \
rhoPi_(24, 2); \
rhoPi_(4, 14); \
rhoPi_(15, 27); \
rhoPi_(23, 41); \
rhoPi_(19, 56); \
rhoPi_(13, 8); \
rhoPi_(12, 25); \
rhoPi_(2, 43); \
rhoPi_(20, 62); \
rhoPi_(14, 18); \
rhoPi_(22, 39); \
rhoPi_(9, 61); \
rhoPi_(6, 20); \
rhoPi_(1, 44);

#define chi_(n) \
b[0] = a[n + 0]; \
b[1] = a[n + 1]; \
b[2] = a[n + 2]; \
b[3] = a[n + 3]; \
b[4] = a[n + 4]; \
a[n + 0] = b[0] ^ ((~b[1]) & b[2]); \
a[n + 1] = b[1] ^ ((~b[2]) & b[3]); \
a[n + 2] = b[2] ^ ((~b[3]) & b[4]); \
a[n + 3] = b[3] ^ ((~b[4]) & b[0]); \
a[n + 4] = b[4] ^ ((~b[0]) & b[1]);

#define chi() chi_(0); chi_(5); chi_(10); chi_(15); chi_(20);

#define iota(x) a[0] ^= x;

#define iteration(x) theta(); rhoPi(); chi(); iota(x);

static inline void keccakf(ulong *a)
{
  ulong b[5];
  ulong t;

  iteration(0x0000000000000001); // iteration 1
  iteration(0x0000000000008082); // iteration 2
  iteration(0x800000000000808a); // iteration 3
  iteration(0x8000000080008000); // iteration 4
  iteration(0x000000000000808b); // iteration 5
  iteration(0x0000000080000001); // iteration 6
  iteration(0x8000000080008081); // iteration 7
  iteration(0x8000000000008009); // iteration 8
  iteration(0x000000000000008a); // iteration 9
  iteration(0x0000000000000088); // iteration 10
  iteration(0x0000000080008009); // iteration 11
  iteration(0x000000008000000a); // iteration 12
  iteration(0x000000008000808b); // iteration 13
  iteration(0x800000000000008b); // iteration 14
  iteration(0x8000000000008089); // iteration 15
  iteration(0x8000000000008003); // iteration 16
  iteration(0x8000000000008002); // iteration 17
  iteration(0x8000000000000080); // iteration 18
  iteration(0x000000000000800a); // iteration 19
  iteration(0x800000008000000a); // iteration 20
  iteration(0x8000000080008081); // iteration 21
  iteration(0x8000000000008080); // iteration 22
  iteration(0x0000000080000001); // iteration 23
  iteration(0x8000000080008008); // iteration 24
}

#if LEADING_ZEROES == 8
#define hasLeading(d) (!(((uint*)d)[0]) && !(((uint*)d)[1]))
#elif LEADING_ZEROES == 7
#define hasLeading(d) (!(((uint*)d)[0]) && !(((uint*)d)[1] & 0x00ffffffu))
#elif LEADING_ZEROES == 6
#define hasLeading(d) (!(((uint*)d)[0]) && !(((uint*)d)[1] & 0x0000ffffu))
#elif LEADING_ZEROES == 5
#define hasLeading(d) (!(((uint*)d)[0]) && !(((uint*)d)[1] & 0x000000ffu))
#elif LEADING_ZEROES == 4
#define hasLeading(d) (!(((uint*)d)[0]))
#elif LEADING_ZEROES == 3
#define hasLeading(d) (!(((uint*)d)[0] & 0x00ffffffu))
#elif LEADING_ZEROES == 2
#define hasLeading(d) (!(((uint*)d)[0] & 0x0000ffffu))
#elif LEADING_ZEROES == 1
#define hasLeading(d) (!(((uint*)d)[0] & 0x000000ffu))
#else
static inline bool hasLeading(uchar const *d)
{
#pragma unroll
  for (uint i = 0; i < LEADING_ZEROES; ++i) {
    if (d[i] != 0) return false;
  }
  return true;
}
#endif

__kernel void hashMessage(
  __constant uchar const *d_message,
  __constant uint const *d_nonce,
  __global volatile ulong *restrict solutions
) {

  ulong spongeBuffer[25];

#define sponge ((uchar *) spongeBuffer)

  nonce_t nonce;

  // 0-19: caller
  sponge[0] = S_0;
  sponge[1] = S_1;
  sponge[2] = S_2;
  sponge[3] = S_3;
  sponge[4] = S_4;
  sponge[5] = S_5;
  sponge[6] = S_6;
  sponge[7] = S_7;
  sponge[8] = S_8;
  sponge[9] = S_9;
  sponge[10] = S_10;
  sponge[11] = S_11;
  sponge[12] = S_12;
  sponge[13] = S_13;
  sponge[14] = S_14;
  sponge[15] = S_15;
  sponge[16] = S_16;
  sponge[17] = S_17;
  sponge[18] = S_18;
  sponge[19] = S_19;
  // 20-51:  salt
  sponge[20] = S_20;
  sponge[21] = S_21;
  sponge[22] = S_22;
  sponge[23] = S_23;
  sponge[24] = S_24;
  sponge[25] = S_25;
  sponge[26] = S_26;
  sponge[27] = S_27;
  sponge[28] = S_28;
  sponge[29] = S_29;
  sponge[30] = S_30;
  sponge[31] = S_31;
  sponge[32] = S_32;
  sponge[33] = S_33;
  sponge[34] = S_34;
  sponge[35] = S_35;
  sponge[36] = S_36;
  sponge[37] = S_37;
  sponge[38] = S_38;
  sponge[39] = S_39;
  sponge[40] = S_40;
  sponge[41] = S_41;
  sponge[42] = S_42;
  sponge[43] = S_43;
  sponge[44] = S_44;
  sponge[45] = S_45;
  sponge[46] = S_46;
  sponge[47] = S_47;
  sponge[48] = S_48;
  sponge[49] = S_49;
  sponge[50] = S_50;
  sponge[51] = S_51;

  // 52-71 first segment of nonce, filled with zeros
#pragma unroll
  for (int i = 52; i < 72; ++i)
    sponge[i] = 0;

  // 72-75 second segment of nonce, first random value
  sponge[72] = d_message[0];
  sponge[73] = d_message[1];
  sponge[74] = d_message[2];
  sponge[75] = d_message[3];

  // populate the nonce
  nonce.uint32_t[0] = get_global_id(0);
  nonce.uint32_t[1] = d_nonce[0];

  // 76-83 third segment of nonce, second+third random values
  sponge[76] = nonce.uint8_t[0];
  sponge[77] = nonce.uint8_t[1];
  sponge[78] = nonce.uint8_t[2];
  sponge[79] = nonce.uint8_t[3];
  sponge[80] = nonce.uint8_t[4];
  sponge[81] = nonce.uint8_t[5];
  sponge[82] = nonce.uint8_t[6];
  sponge[83] = nonce.uint8_t[7];

  // begin padding based on message length
  sponge[84] = 0x01u;

  // fill padding
#pragma unroll
  for (int i = 85; i < 135; ++i)
    sponge[i] = 0;

  // end padding
  sponge[135] = 0x80u;

  // fill remaining sponge state with zeroes
#pragma unroll
  for (int i = 136; i < 200; ++i)
    sponge[i] = 0;

  // Apply keccakf
  keccakf(spongeBuffer);

  // determine if the address meets the constraints
  if (
    hasLeading(sponge)
  ) {
    // To be honest, if we are using OpenCL,
    // we just need to write one solution for all practical purposes,
    // since the chance of multiple solutions appearing
    // in a single workset is extremely low.
    solutions[0] = nonce.uint64_t;
  }
}
