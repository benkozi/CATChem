!> \file test_nuopc_emis_source.F90
!! The extemis source switch (processes/extemis/source: file | nuopc_import) and the emission-open log lines.
!!
!! One executable, one CTest per case (the case name is the first argument); every case runs in
!! tests/emis_source of the build tree, writes its own ESMF log (PET0.emis_source_<case>.log) and reads it
!! back after a flush to check which emission files were opened:
!!   file_reads                source: file; a lat-lon NetCDF (regrid reader) and a volcano .rc table
!!                             (point reader) written here; the open lines name both categories
!!   import_no_reads           source: nuopc_import, every source_file a missing path, every import bound:
!!                             init, binding and two updates succeed and nothing is opened
!!   import_unconnected        as above with one import left out: binding fails by name, no file fallback
!!   import_point_active       an active volcano category under nuopc_import fails setup by name
!!   import_nongridded_active  an active gridded: false category under nuopc_import fails setup by name
!!   import_point_inactive     an inactive volcano category under nuopc_import is accepted
program test_nuopc_emis_source
   use iso_c_binding, only: c_double, c_int, c_ptr
   use ESMF
   use netcdf
   use catchem_nuopc_emis_mod, only: catchem_emis_init, catchem_emis_update, catchem_emis_bind_import, &
      catchem_emis_finish_binding, catchem_emis_read
   use catchem_nuopc_emis_data_mod, only: ExtEmisDataType
   use catchem_bridge_error, only: CC_SUCCESS
   use catchem_bridge_precision, only: fp
   use CATChem_API, only: CATChem_Model

   implicit none

   interface
      integer(c_int) function catchem_state_get_species_count_checked(state, count) &
         bind(C, name="catchem_state_get_species_count_checked")
         import :: c_ptr, c_int
         type(c_ptr), value :: state
         integer(c_int), intent(out) :: count
      end function
   end interface

   integer, parameter :: nx = 4, ny = 3, nz = 5
   character(len=*), parameter :: open_line = 'CATChem: emission open '
   character(len=*), parameter :: aqmio_read_line = 'AQMIO: open iomode=read '

   type(CATChem_Model) :: model
   type(ExtEmisDataType), target :: ext
   type(ESMF_Grid) :: grid
   type(ESMF_GridComp) :: io_unused
   type(ESMF_Clock) :: clock
   type(ESMF_Time) :: start_time, stop_time, now
   type(ESMF_TimeInterval) :: step
   character(len=64) :: case_name
   character(len=128) :: log_name
   real(c_double), allocatable, target :: met_pedge(:,:,:), met_airden(:,:,:), conc_buf(:,:,:)
   integer :: rc, i

   call get_command_argument(1, case_name)
   if (len_trim(case_name) == 0) error stop 'usage: test_nuopc_emis_source <case>'
   log_name = 'emis_source_'//trim(case_name)//'.log'

   call ESMF_Initialize(defaultCalKind=ESMF_CALKIND_GREGORIAN, defaultlogfilename=trim(log_name), &
      logkindflag=ESMF_LOGKIND_MULTI, rc=rc)
   call check(rc, 'ESMF_Initialize')

   grid = ESMF_GridCreateNoPeriDimUfrm(maxIndex=(/nx, ny/), minCornerCoord=(/0.0_ESMF_KIND_R8, -30.0_ESMF_KIND_R8/), &
      maxCornerCoord=(/80.0_ESMF_KIND_R8, 30.0_ESMF_KIND_R8/), coordSys=ESMF_COORDSYS_SPH_DEG, &
      staggerLocList=(/ESMF_STAGGERLOC_CENTER/), rc=rc)
   call check(rc, 'GridCreateNoPeriDimUfrm')
   call ESMF_TimeIntervalSet(step, s=600, rc=rc)
   call check(rc, 'TimeIntervalSet')
   call ESMF_TimeSet(start_time, yy=2021, mm=3, dd=22, h=6, rc=rc)
   call check(rc, 'TimeSet start')
   stop_time = start_time + step + step
   clock = ESMF_ClockCreate(timeStep=step, startTime=start_time, stopTime=stop_time, rc=rc)
   call check(rc, 'ClockCreate')

   select case (trim(case_name))
    case ('file_reads')
      call write_inputs()
      call init_model('file_reads.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc /= CC_SUCCESS) error stop 'FAIL: catchem_emis_init with source: file'
      do i = 1, ext%n_categories
         call catchem_emis_read(ext%categories(i), ext%regrid_cache, io_unused, grid, nz, start_time, rc)
         if (rc /= CC_SUCCESS) then
            print *, 'FAIL: catchem_emis_read for ', trim(ext%categories(i)%category_name)
            error stop 1
         end if
      end do
      call flush_log()
      call require(open_line//'category=surf reader=time_coord path=grid_emis.nc')
      call require(open_line//'category=surf reader=rank_probe path=grid_emis.nc')
      call require(open_line//'category=surf reader=regrid path=grid_emis.nc')
      call require(open_line//'category=volcanic reader=point_rc path=points.rc')
      print *, 'PASS: source: file opens the inventories and logs every open by category and path'

    case ('import_no_reads')
      call init_model('import.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc /= CC_SUCCESS) error stop 'FAIL: catchem_emis_init with source: nuopc_import'
      call bind('surf', 'NO')
      call bind('clim', 'SO2')
      call catchem_emis_finish_binding(ext, rc)
      if (rc /= CC_SUCCESS) error stop 'FAIL: catchem_emis_finish_binding with every import bound'
      call set_state()
      now = start_time
      do i = 1, 2
         call catchem_emis_update(ext, model%cpp_core_ptr, now, nz, io_unused, grid, 600.0_fp, rc)
         if (rc /= CC_SUCCESS) error stop 'FAIL: catchem_emis_update with source: nuopc_import'
         now = now + step
      end do
      call flush_log()
      call forbid(open_line)
      call forbid(aqmio_read_line)
      call forbid('File not found')
      call require('catchem_emis_init: extemis source=nuopc_import')
      print *, 'PASS: source: nuopc_import opens no emission file (missing source_file paths never touched)'

    case ('import_unconnected')
      call init_model('import.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc /= CC_SUCCESS) error stop 'FAIL: catchem_emis_init with source: nuopc_import'
      call bind('clim', 'SO2')
      call catchem_emis_finish_binding(ext, rc)
      if (rc == CC_SUCCESS) error stop 'FAIL: an unconnected import was accepted under source: nuopc_import'
      call flush_log()
      call require('category surf has no connected import extemis_surf_NO (no file fallback)')
      call forbid(open_line)
      print *, 'PASS: an unconnected import fails binding by name, with no file fallback'

    case ('import_point_active')
      call init_model('import_point_active.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc == CC_SUCCESS) error stop 'FAIL: an active point category was accepted under source: nuopc_import'
      call flush_log()
      call require('category volcanic is a point source')
      call require('point sources need source: file')
      print *, 'PASS: an active point category fails setup by name under source: nuopc_import'

    case ('import_nongridded_active')
      call init_model('import_nongridded_active.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc == CC_SUCCESS) error stop 'FAIL: an active non-gridded category was accepted under source: nuopc_import'
      call flush_log()
      call require('category nogrid is a point source')
      call require('point sources need source: file')
      print *, 'PASS: an active non-gridded category fails setup by name under source: nuopc_import'

    case ('import_point_inactive')
      call init_model('import.yml')
      call catchem_emis_init(ext, model%cpp_core_ptr, nx, ny, nz, clock, rc)
      if (rc /= CC_SUCCESS) error stop 'FAIL: an inactive point category was refused under source: nuopc_import'
      do i = 1, ext%n_categories
         if (trim(ext%categories(i)%category_name) == 'volcanic') error stop 'FAIL: the inactive volcanic category was set up'
      end do
      print *, 'PASS: an inactive point category is accepted under source: nuopc_import'

    case default
      print *, 'unknown case: ', trim(case_name)
      error stop 2
   end select

   call ESMF_Finalize(rc=rc)

contains

   subroutine check(rc_in, what)
      integer, intent(in) :: rc_in
      character(len=*), intent(in) :: what
      if (rc_in /= ESMF_SUCCESS) then
         print *, 'FAIL (setup): ', what, ' rc=', rc_in
         error stop 1
      end if
   end subroutine check

   subroutine init_model(config)
      character(len=*), intent(in) :: config
      integer :: irc
      call model%initialize(config, nx, ny, nz, rc=irc)
      if (irc /= 0) then
         print *, 'FAIL (setup): model initialize on ', config, ' rc=', irc
         error stop 1
      end if
   end subroutine init_model

   !> Bind one emission field to a fresh nx x ny x nz import (the provider's allocation in a coupled run).
   subroutine bind(category, field)
      character(len=*), intent(in) :: category, field
      real(ESMF_KIND_R8), pointer :: fptr(:,:,:)
      logical :: bound
      integer :: irc
      allocate(fptr(nx, ny, nz))
      fptr = 1.0e-12_ESMF_KIND_R8
      call catchem_emis_bind_import(ext, category, field, 'extemis_'//category//'_'//field, fptr, nx, ny, nz, bound, irc)
      if (irc /= CC_SUCCESS .or. .not. bound) then
         print *, 'FAIL (setup): binding ', category, '/', field
         error stop 1
      end if
   end subroutine bind

   !> What catchem_emis_apply needs from the host in a coupled run: PEDGE and AIRDEN_DRY, which it converts
   !! by, and the unified chemistry buffer it adds to ((column, level, species), as test_nuopc_diag_output).
   subroutine set_state()
      integer :: k, irc
      integer(c_int) :: n_species
      allocate(met_pedge(nx, ny, nz + 1), met_airden(nx, ny, nz))
      do k = 1, nz + 1
         met_pedge(:,:,k) = 1.0e5_c_double - real(k - 1, c_double) * 1.0e4_c_double
      end do
      met_airden = 1.0_c_double
      call model%bind_met_3d('PEDGE', met_pedge, rc=irc)
      if (irc /= 0) error stop 'FAIL (setup): binding PEDGE'
      call model%bind_met_3d('AIRDEN_DRY', met_airden, rc=irc)
      if (irc /= 0) error stop 'FAIL (setup): binding AIRDEN_DRY'
      if (catchem_state_get_species_count_checked(model%state_mgr_ptr, n_species) /= 0_c_int .or. n_species <= 0) &
         error stop 'FAIL (setup): species count'
      allocate(conc_buf(nx * ny, nz, int(n_species)))
      conc_buf = 1.0e-9_c_double
      call model%bind_unified_chemistry(conc_buf, irc)
      if (irc /= 0) error stop 'FAIL (setup): bind_unified_chemistry'
   end subroutine set_state

   !> The file-path inputs: a lat-lon NetCDF with two hourly records and a two-row volcano table.
   subroutine write_inputs()
      integer :: ncid, dlon, dlat, dtime, vlon, vlat, vtime, vno, unit, j
      real(ESMF_KIND_R8) :: lons(8), lats(6)
      real(ESMF_KIND_R4) :: values(8, 6)
      lons = [(45.0_ESMF_KIND_R8 * (j - 1), j = 1, 8)]
      lats = [(-75.0_ESMF_KIND_R8 + 30.0_ESMF_KIND_R8 * (j - 1), j = 1, 6)]
      values = 1.0e-10
      call nc(nf90_create('grid_emis.nc', NF90_CLOBBER, ncid))
      call nc(nf90_def_dim(ncid, 'lon', 8, dlon))
      call nc(nf90_def_dim(ncid, 'lat', 6, dlat))
      call nc(nf90_def_dim(ncid, 'time', NF90_UNLIMITED, dtime))
      call nc(nf90_def_var(ncid, 'lon', NF90_DOUBLE, [dlon], vlon))
      call nc(nf90_def_var(ncid, 'lat', NF90_DOUBLE, [dlat], vlat))
      call nc(nf90_def_var(ncid, 'time', NF90_DOUBLE, [dtime], vtime))
      call nc(nf90_put_att(ncid, vtime, 'units', 'hours since 2021-03-22 00:00:00'))
      call nc(nf90_def_var(ncid, 'NO', NF90_FLOAT, [dlon, dlat, dtime], vno))
      call nc(nf90_put_att(ncid, vno, 'units', 'kg/m2/s'))
      call nc(nf90_enddef(ncid))
      call nc(nf90_put_var(ncid, vlon, lons))
      call nc(nf90_put_var(ncid, vlat, lats))
      call nc(nf90_put_var(ncid, vtime, [6.0_ESMF_KIND_R8, 7.0_ESMF_KIND_R8]))
      call nc(nf90_put_var(ncid, vno, values, start=[1, 1, 1], count=[8, 6, 1]))
      call nc(nf90_put_var(ncid, vno, values, start=[1, 1, 2], count=[8, 6, 1]))
      call nc(nf90_close(ncid))
      open(newunit=unit, file='points.rc', status='replace', action='write')
      write(unit, '(A)') 'volcano::'
      write(unit, '(A)') '  10.0  20.0  1.0  100.0  2000.0'
      write(unit, '(A)') ' -10.0  60.0  2.0   50.0   500.0'
      write(unit, '(A)') '::'
      close(unit)
   end subroutine write_inputs

   subroutine nc(status)
      integer, intent(in) :: status
      if (status /= NF90_NOERR) then
         print *, 'FAIL (setup): netCDF: ', trim(nf90_strerror(status))
         error stop 1
      end if
   end subroutine nc

   subroutine flush_log()
      integer :: irc
      call ESMF_LogFlush(rc=irc)
      call check(irc, 'LogFlush')
   end subroutine flush_log

   !> Number of lines of this PET's log that contain text.
   integer function log_count(text) result(n)
      character(len=*), intent(in) :: text
      character(len=4096) :: line
      integer :: unit, ios
      n = 0
      open(newunit=unit, file='PET0.'//trim(log_name), status='old', action='read', iostat=ios)
      if (ios /= 0) then
         print *, 'FAIL (setup): cannot open PET0.', trim(log_name)
         error stop 1
      end if
      do
         read(unit, '(A)', iostat=ios) line
         if (ios /= 0) exit
         if (index(line, text) > 0) n = n + 1
      end do
      close(unit)
   end function log_count

   subroutine require(text)
      character(len=*), intent(in) :: text
      if (log_count(text) == 0) then
         print *, 'FAIL: no log line contains: ', text
         error stop 1
      end if
   end subroutine require

   subroutine forbid(text)
      character(len=*), intent(in) :: text
      if (log_count(text) > 0) then
         print *, 'FAIL: a log line contains: ', text
         error stop 1
      end if
   end subroutine forbid

end program test_nuopc_emis_source
