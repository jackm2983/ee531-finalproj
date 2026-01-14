// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_mux4to1.h for the primary calling header

#include "Vtb_mux4to1__pch.h"
#include "Vtb_mux4to1__Syms.h"
#include "Vtb_mux4to1___024root.h"

void Vtb_mux4to1___024root___ctor_var_reset(Vtb_mux4to1___024root* vlSelf);

Vtb_mux4to1___024root::Vtb_mux4to1___024root(Vtb_mux4to1__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , __VdlySched{*symsp->_vm_contextp__}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtb_mux4to1___024root___ctor_var_reset(this);
}

void Vtb_mux4to1___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtb_mux4to1___024root::~Vtb_mux4to1___024root() {
}
