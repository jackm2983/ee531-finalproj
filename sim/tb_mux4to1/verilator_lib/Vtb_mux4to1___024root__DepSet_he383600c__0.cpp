// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_mux4to1.h for the primary calling header

#include "Vtb_mux4to1__pch.h"
#include "Vtb_mux4to1__Syms.h"
#include "Vtb_mux4to1___024root.h"

VL_INLINE_OPT VlCoroutine Vtb_mux4to1___024root___eval_initial__TOP__Vtiming__0(Vtb_mux4to1___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_mux4to1___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb_mux4to1__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    VL_WRITEF_NX("Starting MUX 4:1 Test\nTime\tsel\tin0\tin1\tin2\tin3\tout\n",0);
    vlSelfRef.tb_mux4to1__DOT__in0 = 0xaaU;
    vlSelfRef.tb_mux4to1__DOT__in1 = 0xbbU;
    vlSelfRef.tb_mux4to1__DOT__in2 = 0xccU;
    vlSelfRef.tb_mux4to1__DOT__in3 = 0xddU;
    vlSelfRef.tb_mux4to1__DOT__sel = 0U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         35);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    if ((2U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
            if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
                if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                                  != (IData)(vlSelfRef.tb_mux4to1__DOT__in3))))) {
                    VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:44: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=11\n",0,
                                 64,VL_TIME_UNITED_Q(1000),
                                 -9,vlSymsp->name());
                    VL_STOP_MT("tb_mux4to1.sv", 44, "");
                }
            }
        } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in2))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:43: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=10\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 43, "");
            }
        }
    } else if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in1))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:42: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=01\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 42, "");
            }
        }
    } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
        if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                          != (IData)(vlSelfRef.tb_mux4to1__DOT__in0))))) {
            VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:41: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=00\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("tb_mux4to1.sv", 41, "");
        }
    }
    vlSelfRef.tb_mux4to1__DOT__unnamedblk1__DOT__i = 1U;
    vlSelfRef.tb_mux4to1__DOT__sel = 1U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         35);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    if ((2U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
            if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
                if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                                  != (IData)(vlSelfRef.tb_mux4to1__DOT__in3))))) {
                    VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:44: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=11\n",0,
                                 64,VL_TIME_UNITED_Q(1000),
                                 -9,vlSymsp->name());
                    VL_STOP_MT("tb_mux4to1.sv", 44, "");
                }
            }
        } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in2))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:43: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=10\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 43, "");
            }
        }
    } else if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in1))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:42: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=01\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 42, "");
            }
        }
    } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
        if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                          != (IData)(vlSelfRef.tb_mux4to1__DOT__in0))))) {
            VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:41: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=00\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("tb_mux4to1.sv", 41, "");
        }
    }
    vlSelfRef.tb_mux4to1__DOT__unnamedblk1__DOT__i = 2U;
    vlSelfRef.tb_mux4to1__DOT__sel = 2U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         35);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    if ((2U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
            if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
                if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                                  != (IData)(vlSelfRef.tb_mux4to1__DOT__in3))))) {
                    VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:44: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=11\n",0,
                                 64,VL_TIME_UNITED_Q(1000),
                                 -9,vlSymsp->name());
                    VL_STOP_MT("tb_mux4to1.sv", 44, "");
                }
            }
        } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in2))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:43: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=10\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 43, "");
            }
        }
    } else if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in1))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:42: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=01\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 42, "");
            }
        }
    } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
        if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                          != (IData)(vlSelfRef.tb_mux4to1__DOT__in0))))) {
            VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:41: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=00\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("tb_mux4to1.sv", 41, "");
        }
    }
    vlSelfRef.tb_mux4to1__DOT__unnamedblk1__DOT__i = 3U;
    vlSelfRef.tb_mux4to1__DOT__sel = 3U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         35);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    if ((2U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
            if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
                if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                                  != (IData)(vlSelfRef.tb_mux4to1__DOT__in3))))) {
                    VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:44: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=11\n",0,
                                 64,VL_TIME_UNITED_Q(1000),
                                 -9,vlSymsp->name());
                    VL_STOP_MT("tb_mux4to1.sv", 44, "");
                }
            }
        } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in2))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:43: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=10\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 43, "");
            }
        }
    } else if ((1U & (IData)(vlSelfRef.tb_mux4to1__DOT__sel))) {
        if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
            if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                              != (IData)(vlSelfRef.tb_mux4to1__DOT__in1))))) {
                VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:42: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=01\n",0,
                             64,VL_TIME_UNITED_Q(1000),
                             -9,vlSymsp->name());
                VL_STOP_MT("tb_mux4to1.sv", 42, "");
            }
        }
    } else if (vlSymsp->_vm_contextp__->assertOnGet(2, 1)) {
        if (VL_UNLIKELY((((IData)(vlSelfRef.tb_mux4to1__DOT__out) 
                          != (IData)(vlSelfRef.tb_mux4to1__DOT__in0))))) {
            VL_WRITEF_NX("[%0t] %%Error: tb_mux4to1.sv:41: Assertion failed in %Ntb_mux4to1.unnamedblk1: Mismatch for sel=00\n",0,
                         64,VL_TIME_UNITED_Q(1000),
                         -9,vlSymsp->name());
            VL_STOP_MT("tb_mux4to1.sv", 41, "");
        }
    }
    vlSelfRef.tb_mux4to1__DOT__unnamedblk1__DOT__i = 4U;
    vlSelfRef.tb_mux4to1__DOT__in0 = 0x11U;
    vlSelfRef.tb_mux4to1__DOT__in1 = 0x22U;
    vlSelfRef.tb_mux4to1__DOT__in2 = 0x33U;
    vlSelfRef.tb_mux4to1__DOT__in3 = 0x44U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         50);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    vlSelfRef.tb_mux4to1__DOT__sel = 0U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         54);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    vlSelfRef.tb_mux4to1__DOT__unnamedblk2__DOT__i = 1U;
    vlSelfRef.tb_mux4to1__DOT__sel = 1U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         54);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    vlSelfRef.tb_mux4to1__DOT__unnamedblk2__DOT__i = 2U;
    vlSelfRef.tb_mux4to1__DOT__sel = 2U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         54);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    vlSelfRef.tb_mux4to1__DOT__unnamedblk2__DOT__i = 3U;
    vlSelfRef.tb_mux4to1__DOT__sel = 3U;
    co_await vlSelfRef.__VdlySched.delay(0x2710ULL, 
                                         nullptr, "tb_mux4to1.sv", 
                                         54);
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    VL_WRITEF_NX("%0t\t%b\t%x\t%x\t%x\t%x\t%x\n",0,
                 64,VL_TIME_UNITED_Q(1000),-9,2,(IData)(vlSelfRef.tb_mux4to1__DOT__sel),
                 8,vlSelfRef.tb_mux4to1__DOT__in0,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in1),
                 8,vlSelfRef.tb_mux4to1__DOT__in2,8,
                 (IData)(vlSelfRef.tb_mux4to1__DOT__in3),
                 8,vlSelfRef.tb_mux4to1__DOT__out);
    vlSelfRef.tb_mux4to1__DOT__unnamedblk2__DOT__i = 4U;
    VL_WRITEF_NX("Test Complete\n",0);
    VL_FINISH_MT("tb_mux4to1.sv", 60, "");
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_mux4to1___024root___dump_triggers__act(Vtb_mux4to1___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_mux4to1___024root___eval_triggers__act(Vtb_mux4to1___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_mux4to1___024root___eval_triggers__act\n"); );
    Vtb_mux4to1__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered.set(0U, vlSelfRef.__VdlySched.awaitingCurrentTime());
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_mux4to1___024root___dump_triggers__act(vlSelf);
    }
#endif
}
