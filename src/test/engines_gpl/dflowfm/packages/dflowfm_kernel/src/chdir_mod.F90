!!  Copyright (C)  Stichting Deltares, 2012-2026.
!!
!!  This program is free software: you can redistribute it and/or modify
!!  it under the terms of the GNU General Public License version 3,
!!  as published by the Free Software Foundation.
!!
!!  This program is distributed in the hope that it will be useful,
!!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!!  GNU General Public License for more details.
!!
!!  You should have received a copy of the GNU General Public License
!!  along with this program. If not, see <http://www.gnu.org/licenses/>.
!!
!!  contact: delft3d.support@deltares.nl
!!  Stichting Deltares
!!  P.O. Box 177
!!  2600 MH Delft, The Netherlands
!!
!!  All indications and logos of, and references to registered trademarks
!!  of Stichting Deltares remain the property of Stichting Deltares. All
!!  rights reserved.
!> Change the current working directory.
!!
!! The C library's chdir is bound directly, except with the Intel compilers,
!! which use ifport's CHANGEDIRQQ: that is what keeps the Windows build working,
!! where the C library spells the function _chdir. The preprocessor selects
!! between the two, so this file is compiled with preprocessing on.
module chdir_mod
#if defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)
   use ifport, only: CHANGEDIRQQ
#else
   use iso_c_binding, only: c_char, c_null_char
#endif

   implicit none
   private
   public :: chdir

#if !defined(__INTEL_COMPILER) && !defined(__INTEL_LLVM_COMPILER)
   interface
      integer function c_chdir(path) bind(C, name="chdir")
         use iso_c_binding, only: c_char
         character(kind=c_char) :: path(*)
      end function c_chdir
   end interface
#endif

contains

   !> Change to directory path, without the trailing blanks of a longer variable.
   !! err, when present, is the status of the underlying call: 0 on success.
   subroutine chdir(path, err)
      character(*), intent(in) :: path
      integer, optional, intent(out) :: err

#if defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)
      logical :: ok

      ok = CHANGEDIRQQ(path)
      if (present(err)) then
         if (ok) then
            err = 0
         else
            err = 1
         end if
      end if
#else
      integer :: loc_err

      loc_err = c_chdir(trim(path)//c_null_char)
      if (present(err)) err = loc_err
#endif
   end subroutine chdir

end module chdir_mod
