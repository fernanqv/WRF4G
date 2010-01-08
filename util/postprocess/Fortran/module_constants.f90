MODULE module_constants
! Diagnostic modules with constants of computation of atmospheric doagnostic variables from netcdf files
! GMS. UC: December 2009. version v0.0
!
!!!!!!!!!! COMPILATION
!
!! OCEANO: pgf90 module_constants.f90 -L/software/ScientificLinux/4.6/netcdf/3.6.3/pgf716_gcc/lib -lnetcdf -lm -I/software/ScientificLinux/4.6/netcdf/3.6.3/pgf716_gcc/include -Mfree -c

  IMPLICIT NONE

!  456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789

  REAL, PARAMETER                                          :: Pi=3.141596
  REAL, PARAMETER                                          :: Rt=6371227.
  REAL, PARAMETER                                          :: g=9.807
  REAL, PARAMETER                                          :: rocp=2./7.
  REAL, PARAMETER                                          :: tkelvin=273.15

!!!!!!!!!!!!!!!!!! Variables
!      Pi: number pi [ACOS(-1.)]
!      Rt:  
!      g: gravity acceleration [ms-2]
!      rocp: 
!      tkelvin: conversion from celsius degrees to kelvin [K]

END MODULE module_constants
