// mul_stress_led.c — LED stopwatch microbenchmark (maximize MUL fraction)
// Measure time from first all-ON to final all-ON; run once with stock, once with enhanced.

#include <neorv32.h>
#include <stdint.h>

#ifndef N_BLOCKS
#define N_BLOCKS 1800000u  // ~5–10 s at 50 MHz: tune to board clock
#endif

static inline void leds(uint8_t v){ neorv32_gpio_port_set(v); }

// Force MUL (funct7=1, funct3=000) via .insn; keep dependency to prevent reordering
static inline uint32_t mul_u32(uint32_t a, uint32_t b){
  uint32_t r;
  __asm__ volatile(".insn r 0x33,0,1,%0,%1,%2"
                   : "=r"(r) : "r"(a), "r"(b) : /* no clobbers */);
  return r;
}

int main(void){
  if (neorv32_gpio_available() == 0) { for(;;){} }

  // START: all LEDs ON briefly, then OFF to mark the timing window
  leds(0xFF);
  for(volatile uint32_t i=0;i< (50u*1000000u/20u);i++){ __asm__ volatile("nop"); } // ~0.5s @50 MHz
  leds(0x00);
  for(volatile uint32_t i=0;i< (50u*1000000u/20u);i++){ __asm__ volatile("nop"); } // ~0.5s @50 MHz

  // MUL-dominated workload: 16 MULs per block, minimal integer overhead
  uint32_t a = 0xDEADBEEFu;
  uint32_t b = 0x9E3779B9u;  // non-trivial constant (not a power of two)
  uint32_t s = 1u;

  for(uint32_t i=0;i<N_BLOCKS;i++){
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, b);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    s = mul_u32(s, a);
    // minimal evolution to avoid constant folding while keeping overhead tiny
    a ^= (i | 1u);
  }

  // DONE: all LEDs ON steady
  leds(0xFF);
  (void)s; // keep 's' alive
  for(;;){}
}
