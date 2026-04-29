!> \file test_Constants.f90
!! \brief Test program for Constants module
!!
!!!>
program test_Constants
   use testing_mod, only: assert, assert_close
   use Constants, only: PI, PI_180, AVO, BOLTZ, RSTARG, AIRMW, H2OMW, ATM
   use Precision_Mod, only: fp

   implicit none

   write(*,*) 'Testing Constants module...'
   write(*,*) ''

   ! Test 1: Mathematical constants
   write(*,*) 'Test 1: Mathematical constants'
   call assert(PI > 3.14159_fp .and. PI < 3.14160_fp, "PI should be approximately 3.14159")
   call assert(PI_180 > 0.01745_fp .and. PI_180 < 0.01746_fp, "PI_180 should be approximately 0.01745")

   write(*,*) 'Test 1 passed!'
   write(*,*) ''

   ! Test 2: Physical constants
   write(*,*) 'Test 2: Physical constants'
   call assert(AVO > 6.022e23_fp .and. AVO < 6.023e23_fp, "AVO should be approximately 6.022e23")
   call assert(BOLTZ > 1.380e-23_fp .and. BOLTZ < 1.381e-23_fp, "BOLTZ should be approximately 1.380e-23")
   call assert(RSTARG > 8.314_fp .and. RSTARG < 8.315_fp, "RSTARG should be approximately 8.314")

   write(*,*) 'Test 2 passed!'
   write(*,*) ''

   ! Test 3: Molecular weights
   write(*,*) 'Test 3: Molecular weights'
   call assert(AIRMW > 28.96_fp .and. AIRMW < 28.97_fp, "AIRMW should be approximately 28.96")
   call assert(H2OMW > 18.01_fp .and. H2OMW < 18.02_fp, "H2OMW should be approximately 18.01")

   write(*,*) 'Test 3 passed!'
   write(*,*) ''

   ! Test 4: Atmospheric constants
   write(*,*) 'Test 4: Atmospheric constants'
   call assert(ATM > 101324.0_fp .and. ATM < 101326.0_fp, "ATM should be approximately 101325")

   write(*,*) 'Test 4 passed!'
   write(*,*) ''

   write(*,*) 'All Constants tests passed!'

end program test_Constants
