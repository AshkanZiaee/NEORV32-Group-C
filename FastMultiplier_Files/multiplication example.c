#include <stdint.h>
#include "neorv32.h"

// Busy-wait only; no timers/CSRs
static inline void wait_loops(uint32_t n){ for(volatile uint32_t i=0;i<n;i++){ __asm__ volatile("nop"); } }
static inline void led(uint8_t v){ neorv32_gpio_port_set(v); }

// 64-bit software references
static inline uint32_t ref_mul_lo(uint32_t a, uint32_t b){ return (uint32_t)((uint64_t)a * (uint64_t)b); }
static inline uint32_t ref_mulh_ss(int32_t a, int32_t b){ int64_t p=(int64_t)a*(int64_t)b; return (uint32_t)((uint64_t)p>>32); }
static inline uint32_t ref_mulh_su(int32_t a, uint32_t b){ int64_t p=(int64_t)a*(uint64_t)b; return (uint32_t)((uint64_t)p>>32); }
static inline uint32_t ref_mulh_uu(uint32_t a, uint32_t b){ uint64_t p=(uint64_t)a*(uint64_t)b; return (uint32_t)(p>>32); }

// Hardware ops via .insn (OP=0x33, funct7=1)
static inline uint32_t hw_mul(uint32_t a, uint32_t b){
  uint32_t r; __asm__ volatile(".insn r 0x33, 0, 1, %0, %1, %2":"=r"(r):"r"(a),"r"(b)); return r;
}
static inline uint32_t hw_mulh(int32_t a, int32_t b){
  uint32_t r; __asm__ volatile(".insn r 0x33, 1, 1, %0, %1, %2":"=r"(r):"r"(a),"r"(b)); return r;
}
static inline uint32_t hw_mulhsu(int32_t a, uint32_t b){
  uint32_t r; __asm__ volatile(".insn r 0x33, 2, 1, %0, %1, %2":"=r"(r):"r"(a),"r"(b)); return r;
}
static inline uint32_t hw_mulhu(uint32_t a, uint32_t b){
  uint32_t r; __asm__ volatile(".insn r 0x33, 3, 1, %0, %1, %2":"=r"(r):"r"(a),"r"(b)); return r;
}

int main(void){
  // Orientation cue
  led(0xAA); wait_loops(300000);
  led(0x55); wait_loops(300000);
  led(0x00); wait_loops(150000);

  // Operands
  int32_t  sa = -7, sb = 3;
  uint32_t ua =  7u, ub = 3u;

  // Four tests
  uint8_t t0_pass = (hw_mul(ua, ub)     == ref_mul_lo(ua, ub))     ? 1u : 0u; // MUL
  uint8_t t1_pass = (hw_mulh(sa, sb)    == ref_mulh_ss(sa, sb))    ? 1u : 0u; // MULH
  uint8_t t2_pass = (hw_mulhsu(sa, ub)  == ref_mulh_su(sa, ub))    ? 1u : 0u; // MULHSU
  uint8_t t3_pass = (hw_mulhu(ua, ub)   == ref_mulh_uu(ua, ub))    ? 1u : 0u; // MULHU

  // Per-test pair mapping:
  //  Test0: LED7 pass, LED6 fail
  //  Test1: LED5 pass, LED4 fail
  //  Test2: LED3 pass, LED2 fail
  //  Test3: LED1 pass, LED0 fail
  uint8_t leds = 0;
  leds |= t0_pass ? 0x80 : 0x40;
  leds |= t1_pass ? 0x20 : 0x10;
  leds |= t2_pass ? 0x08 : 0x04;
  leds |= t3_pass ? 0x02 : 0x01;

  led(leds);
  while(1){ /* hold steady */ }
}
