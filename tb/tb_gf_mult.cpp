// SPDX-License-Identifier: MIT
#include "Vgf_mult.h"
#include "verilated.h"

#include <cassert>
#include <cstdint>
#include <random>

static std::uint16_t reference_multiply(std::uint16_t a, std::uint16_t b) {
    std::uint32_t product = 0;
    for (unsigned bit = 0; bit < 11; ++bit)
        if ((b >> bit) & 1U) product ^= static_cast<std::uint32_t>(a) << bit;
    for (int bit = 21; bit >= 11; --bit)
        if ((product >> bit) & 1U) product ^= 0x805U << (bit - 11);
    return static_cast<std::uint16_t>(product & 0x7ffU);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vgf_mult dut;
    std::mt19937 random(1);

    for (unsigned i = 0; i < 10000; ++i) {
        dut.a = random() & 0x7ffU;
        dut.b = random() & 0x7ffU;
        dut.eval();
        assert(dut.p == reference_multiply(dut.a, dut.b));
    }

    dut.final();
}
