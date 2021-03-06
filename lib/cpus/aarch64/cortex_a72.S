/*
 * Copyright (c) 2015-2017, ARM Limited and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#include <arch.h>
#include <asm_macros.S>
#include <assert_macros.S>
#include <cortex_a72.h>
#include <cpu_macros.S>
#include <plat_macros.S>

	/* ---------------------------------------------
	 * Disable L1 data cache and unified L2 cache
	 * ---------------------------------------------
	 */
func cortex_a72_disable_dcache
	mrs	x1, sctlr_el3
	bic	x1, x1, #SCTLR_C_BIT
	msr	sctlr_el3, x1
	isb
	ret
endfunc cortex_a72_disable_dcache

	/* ---------------------------------------------
	 * Disable all types of L2 prefetches.
	 * ---------------------------------------------
	 */
func cortex_a72_disable_l2_prefetch
	mrs	x0, CORTEX_A72_ECTLR_EL1
	orr	x0, x0, #CORTEX_A72_ECTLR_DIS_TWD_ACC_PFTCH_BIT
	mov	x1, #CORTEX_A72_ECTLR_L2_IPFTCH_DIST_MASK
	orr	x1, x1, #CORTEX_A72_ECTLR_L2_DPFTCH_DIST_MASK
	bic	x0, x0, x1
	msr	CORTEX_A72_ECTLR_EL1, x0
	isb
	ret
endfunc cortex_a72_disable_l2_prefetch

	/* ---------------------------------------------
	 * Disable the load-store hardware prefetcher.
	 * ---------------------------------------------
	 */
func cortex_a72_disable_hw_prefetcher
	mrs	x0, CORTEX_A72_CPUACTLR_EL1
	orr	x0, x0, #CORTEX_A72_CPUACTLR_EL1_DISABLE_L1_DCACHE_HW_PFTCH
	msr	CORTEX_A72_CPUACTLR_EL1, x0
	isb
	dsb	ish
	ret
endfunc cortex_a72_disable_hw_prefetcher

	/* ---------------------------------------------
	 * Disable intra-cluster coherency
	 * ---------------------------------------------
	 */
func cortex_a72_disable_smp
	mrs	x0, CORTEX_A72_ECTLR_EL1
	bic	x0, x0, #CORTEX_A72_ECTLR_SMP_BIT
	msr	CORTEX_A72_ECTLR_EL1, x0
	ret
endfunc cortex_a72_disable_smp

	/* ---------------------------------------------
	 * Disable debug interfaces
	 * ---------------------------------------------
	 */
func cortex_a72_disable_ext_debug
	mov	x0, #1
	msr	osdlr_el1, x0
	isb
	dsb	sy
	ret
endfunc cortex_a72_disable_ext_debug

	/* -------------------------------------------------
	 * The CPU Ops reset function for Cortex-A72.
	 * -------------------------------------------------
	 */
func cortex_a72_reset_func
	/* ---------------------------------------------
	 * As a bare minimum enable the SMP bit.
	 * ---------------------------------------------
	 */
	mrs	x0, CORTEX_A72_ECTLR_EL1
	orr	x0, x0, #CORTEX_A72_ECTLR_SMP_BIT
	msr	CORTEX_A72_ECTLR_EL1, x0
	isb
	ret
endfunc cortex_a72_reset_func

	/* ----------------------------------------------------
	 * The CPU Ops core power down function for Cortex-A72.
	 * ----------------------------------------------------
	 */
func cortex_a72_core_pwr_dwn
	mov	x18, x30

	/* ---------------------------------------------
	 * Turn off caches.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_dcache

	/* ---------------------------------------------
	 * Disable the L2 prefetches.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_l2_prefetch

	/* ---------------------------------------------
	 * Disable the load-store hardware prefetcher.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_hw_prefetcher

	/* ---------------------------------------------
	 * Flush L1 caches.
	 * ---------------------------------------------
	 */
	mov	x0, #DCCISW
	bl	dcsw_op_level1

	/* ---------------------------------------------
	 * Come out of intra cluster coherency
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_smp

	/* ---------------------------------------------
	 * Force the debug interfaces to be quiescent
	 * ---------------------------------------------
	 */
	mov	x30, x18
	b	cortex_a72_disable_ext_debug
endfunc cortex_a72_core_pwr_dwn

	/* -------------------------------------------------------
	 * The CPU Ops cluster power down function for Cortex-A72.
	 * -------------------------------------------------------
	 */
func cortex_a72_cluster_pwr_dwn
	mov	x18, x30

	/* ---------------------------------------------
	 * Turn off caches.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_dcache

	/* ---------------------------------------------
	 * Disable the L2 prefetches.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_l2_prefetch

	/* ---------------------------------------------
	 * Disable the load-store hardware prefetcher.
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_hw_prefetcher

#if !SKIP_A72_L1_FLUSH_PWR_DWN
	/* ---------------------------------------------
	 * Flush L1 caches.
	 * ---------------------------------------------
	 */
	mov	x0, #DCCISW
	bl	dcsw_op_level1
#endif

	/* ---------------------------------------------
	 * Disable the optional ACP.
	 * ---------------------------------------------
	 */
	bl	plat_disable_acp

	/* -------------------------------------------------
	 * Flush the L2 caches.
	 * -------------------------------------------------
	 */
	mov	x0, #DCCISW
	bl	dcsw_op_level2

	/* ---------------------------------------------
	 * Come out of intra cluster coherency
	 * ---------------------------------------------
	 */
	bl	cortex_a72_disable_smp

	/* ---------------------------------------------
	 * Force the debug interfaces to be quiescent
	 * ---------------------------------------------
	 */
	mov	x30, x18
	b	cortex_a72_disable_ext_debug
endfunc cortex_a72_cluster_pwr_dwn

	/* ---------------------------------------------
	 * This function provides cortex_a72 specific
	 * register information for crash reporting.
	 * It needs to return with x6 pointing to
	 * a list of register names in ascii and
	 * x8 - x15 having values of registers to be
	 * reported.
	 * ---------------------------------------------
	 */
.section .rodata.cortex_a72_regs, "aS"
cortex_a72_regs:  /* The ascii list of register names to be reported */
	.asciz	"cpuectlr_el1", "cpumerrsr_el1", "l2merrsr_el1", ""

func cortex_a72_cpu_reg_dump
	adr	x6, cortex_a72_regs
	mrs	x8, CORTEX_A72_ECTLR_EL1
	mrs	x9, CORTEX_A72_MERRSR_EL1
	mrs	x10, CORTEX_A72_L2MERRSR_EL1
	ret
endfunc cortex_a72_cpu_reg_dump


declare_cpu_ops cortex_a72, CORTEX_A72_MIDR, \
	cortex_a72_reset_func, \
	cortex_a72_core_pwr_dwn, \
	cortex_a72_cluster_pwr_dwn
