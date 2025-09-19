// mul_sanity.c — LED-only sanity checks for MUL, MULH, MULHSU, MULHU on NEORV32
// Pair mapping (MSB->LSB): [LED8 pass | LED7 fail]=MUL, [LED6 pass | LED5 fail]=MULH,
//                           [LED4 pass | LED3 fail]=MULHSU, [LED2 pass | LED1 fail]=MULHU

#include <neorv32.h>
#include <stdint.h>

// 64-bit software references (spec semantics)
static inline uint32_t ref_mul_lo(uint32_t a, uint32_t b){
  return (uint32_t)((uint64_t)a * (uint64_t)b);
}
static inline uint32_t ref_mulh_ss(int32_t a, int32_t b){
  int64_t p = (int64_t)a * (int64_t)b;
  return (uint32_t)(p >> 32);
}
static inline uint32_t ref_mulh_su(int32_t a, uint32_t b){
  int64_t p = (int64_t)a * (uint64_t)b;
  return (uint32_t)(p >> 32);
}
static inline uint32_t ref_mulh_uu(uint32_t a, uint32_t b){
  uint64_t p = (uint64_t)a * (uint64_t)b;
  return (uint32_t)(p >> 32);
}

// Hardware ops via inline .insn (R-type opcode=0x33, funct7=1 for M-group)
static inline uint32_t hw_mul(uint32_t a, uint32_t b){
  uint32_t r;
  __asm__ volatile(".insn r 0x33,0,1,%0,%1,%2" : "=r"(r) : "r"(a), "r"(b));
  return r;
}
static inline uint32_t hw_mulh(int32_t a, int32_t b){
  uint32_t r;
  __asm__ volatile(".insn r 0x33,1,1,%0,%1,%2" : "=r"(r) : "r"(a), "r"(b));
  return r;
}
static inline uint32_t hw_mulhsu(int32_t a, uint32_t b){
  uint32_t r;
  __asm__ volatile(".insn r 0x33,2,1,%0,%1,%2" : "=r"(r) : "r"(a), "r"(b));
  return r;
}
static inline uint32_t hw_mulhu(uint32_t a, uint32_t b){
  uint32_t r;
  __asm__ volatile(".insn r 0x33,3,1,%0,%1,%2" : "=r"(r) : "r"(a), "r"(b));
  return r;
}

// Small wait for visible LED patterns
static inline void wait_loops(uint32_t n){
  for(volatile uint32_t i=0;i<n;i++){ __asm__ volatile("nop"); }
}

int main(void) {

  // Optional: check GPIO exists
  if (neorv32_gpio_available() == 0) {
    for(;;){} // no GPIO present
  }

  // Ready markers (optional)
  neorv32_gpio_port_set(0xAA); wait_loops(300000);
  neorv32_gpio_port_set(0x55); wait_loops(300000);
  neorv32_gpio_port_set(0x00); wait_loops(150000);

  // Test vectors (simple and sign-sensitive)
  const uint32_t u_a = 7u, u_b = 3u;         // 7*3=21 -> low=0x15, high=0x00000000
  const int32_t  s_a = -7,  s_b = 3;         // -7*3=-21 -> high=0xFFFFFFFF

  uint8_t leds = 0;

  // MUL: unsigned*unsigned -> low 32
  {
    uint32_t hw = hw_mul(u_a, u_b);
    uint32_t sw = ref_mul_lo(u_a, u_b);
    if (hw == sw) leds |= 0x80; else leds |= 0x40; // LED8 pass, LED7 fail
  }

  // MULH: signed*signed -> high 32
  {
    uint32_t hw = hw_mulh(s_a, s_b);
    uint32_t sw = ref_mulh_ss(s_a, s_b);
    if (hw == sw) leds |= 0x20; else leds |= 0x10; // LED6 pass, LED5 fail
  }

  // MULHSU: signed*unsigned -> high 32
  {
    uint32_t hw = hw_mulhsu(s_a, u_b);
    uint32_t sw = ref_mulh_su(s_a, u_b);
    if (hw == sw) leds |= 0x08; else leds |= 0x04; // LED4 pass, LED3 fail
  }

  // MULHU: unsigned*unsigned -> high 32
  {
    uint32_t hw = hw_mulhu(u_a, u_b);
    uint32_t sw = ref_mulh_uu(u_a, u_b);
    if (hw == sw) leds |= 0x02; else leds |= 0x01; // LED2 pass, LED1 fail
  }

  // Show final steady pattern
  neorv32_gpio_port_set(leds);
  for(;;){} // hold result
}
