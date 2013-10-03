program full_cycle_surface_binary_mass
!$$$  documentation block
!                .      .    .                                       .
!   full_cycle_surface_netcdf_mass: read surface variables from latest wrf forecast
!        in mass binary valid at the same time as background fields 
!        and update them in wrf mass background file
!
!  List of variables updated:
!       SMOIS
!       SNOW
!       SNOWH
!       SNOWC
!       SST
!    if surface data are in the same time with background data
!       CANWAT
!       SOILT1
!       TSLB
!       TSK
!    if surface data are older than background data
!       TSLB(3,4,5,6)
!         for snow grid point
!           SOILT1
!           TSK
!           TSLB(1,2)
!    Now, for the consistence, we add the following surface index fields
!       LANDMASK
!       XLAND
!       LU_INDEX
!       ISLTYP
!       IVGTYP
!
!   prgmmr: Ming Hu                 date: 2010-07-26
!
! program history log:
!   Ming Hu    date: 2013-06-04  : update to RAPv2 based on netcdf version
!


  use mpi
  use kinds, only: r_single,i_llong,i_kind

  IMPLICIT NONE

!
! MPI variables
  integer :: npe, mype, mypeLocal,ierror

! for background file
  integer(i_kind),allocatable:: start_block(:),end_block(:)
  integer(i_kind),allocatable:: start_byte(:),end_byte(:)
  integer(i_llong),allocatable:: file_offset(:)
  character(132),allocatable:: datestr_all(:),varname_all(:),memoryorder_all(:)
  integer(i_kind),allocatable:: domainend_all(:,:)
  integer(i_kind) nrecs
  CHARACTER(9)  :: filename
  integer(i_kind) :: iunit

! for background file
  integer(i_kind),allocatable:: start_block_sfc(:),end_block_sfc(:)
  integer(i_kind),allocatable:: start_byte_sfc(:),end_byte_sfc(:)
  integer(i_llong),allocatable:: file_offset_sfc(:)
  character(132),allocatable:: datestr_all_sfc(:),varname_all_sfc(:),memoryorder_all_sfc(:)
  integer(i_kind),allocatable:: domainend_all_sfc(:,:)
  integer(i_kind) nrecs_sfc
  CHARACTER(9)  :: filename_sfc
  integer(i_kind) :: iunit_sfc
!
  integer(i_kind) status_hdr
  integer(i_kind) hdrbuf(512)

  CHARACTER (LEN=19)  :: VarName
  logical :: if_integer
!
!
  INTEGER :: istatus,iret,ierr
  INTEGER :: n
  INTEGER :: iyear,imn,iday,ihrst,imin
  integer(i_kind) :: iw3jdn,JDATE(8),IDATE(8)
  real(r_single) :: rinc(5), timediff
  logical :: ifswap

!**********************************************************************
!
!            END OF DECLARATIONS....start of program
! MPI setup
  call MPI_INIT(ierror)
  call MPI_COMM_SIZE(mpi_comm_world,npe,ierror)
  call MPI_COMM_RANK(mpi_comm_world,mype,ierror)
  
  ifswap=.true.

!!! MPI IO

! open and check background file
  iunit=33
  fileName='wrf_inout'
  open(iunit,file=trim(fileName),form='unformatted')
! Check for valid input file
  read(iunit,iostat=status_hdr)hdrbuf
  if(status_hdr /= 0) then
     write(6,*)'full_cycle_surface_binary_mass:  problem with = ',&
          trim(fileName),', Status = ',status_hdr
     call stop2(74)
  endif
  close(iunit)

  iunit_sfc=44
  fileName_sfc='wrfoutSfc'
  open(iunit_sfc,file=trim(fileName_sfc),form='unformatted')
! Check for valid input file
  read(iunit_sfc,iostat=status_hdr)hdrbuf
  if(status_hdr /= 0) then
     write(6,*)'full_cycle_surface_binary_mass:  problem with = ',&
          trim(fileName_sfc),', Status = ',status_hdr
     call stop2(74)
  endif
  close(iunit_sfc)

!
!  inventory both files
!
! first background file
  call count_recs_wrf_binary_file(iunit, ifswap,trim(fileName), nrecs)
  write(*,*) 'number of records in ',trim(fileName), '=', nrecs

  allocate(datestr_all(nrecs),varname_all(nrecs),domainend_all(3,nrecs))
  allocate(memoryorder_all(nrecs))
  allocate(start_block(nrecs),end_block(nrecs))
  allocate(start_byte(nrecs),end_byte(nrecs),file_offset(nrecs))

  call inventory_wrf_binary_file(iunit, ifswap,trim(filename), nrecs,  &
                      datestr_all,varname_all,memoryorder_all,domainend_all,   &
                      start_block,end_block,start_byte,end_byte,file_offset)

!  do N=1,NRECS
!     write(*,'(i4,2x,a30,a5,3i5)') N, trim(varname_all(N)),trim(memoryorder_all(n)),domainend_all(:,n)  
!  enddo

  read(datestr_all(100),15)iyear,imn,iday,ihrst,imin
  write(*,*) 'Current date and time for background = ',iyear,imn,iday,ihrst,imin

  IDATE=0
  IDATE(1)=iyear
  IDATE(2)=imn
  IDATE(3)=iday
  IDATE(5)=ihrst
  IDATE(6)=imin

  close(iunit)

! Then surface file
  call count_recs_wrf_binary_file(iunit_sfc, ifswap,trim(fileName_sfc), nrecs_sfc)
  write(*,*) 'number of records in ',trim(fileName_sfc), '=', nrecs_sfc

  allocate(datestr_all_sfc(nrecs_sfc),varname_all_sfc(nrecs_sfc),domainend_all_sfc(3,nrecs_sfc))
  allocate(memoryorder_all_sfc(nrecs_sfc))
  allocate(start_block_sfc(nrecs_sfc),end_block_sfc(nrecs_sfc))
  allocate(start_byte_sfc(nrecs_sfc),end_byte_sfc(nrecs_sfc),file_offset_sfc(nrecs_sfc))

  call inventory_wrf_binary_file(iunit_sfc, ifswap,trim(filename_sfc), nrecs_sfc,  &
                      datestr_all_sfc,varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,   &
                      start_block_sfc,end_block_sfc,start_byte_sfc,end_byte_sfc,file_offset_sfc)

!  do N=1,NRECS_sfc
!     write(*,'(i4,2x,a30,a5,3i5)') N, trim(varname_all_sfc(N)),trim(memoryorder_all_sfc(n)),domainend_all_sfc(:,n)
!  enddo

  read(datestr_all_sfc(100),15)iyear,imn,iday,ihrst,imin
  write(*,*) 'Current date and time for surface = ',iyear,imn,iday,ihrst,imin
  JDATE=0
  JDATE(1)=iyear
  JDATE(2)=imn
  JDATE(3)=iday
  JDATE(5)=ihrst
  JDATE(6)=imin

  close(iunit_sfc)

15   format(i4,1x,i2,1x,i2,1x,i2,1x,i2)

! find time difference
  rinc(1)=iw3jdn(jdate(1),jdate(2),jdate(3))-  &
          iw3jdn(idate(1),idate(2),idate(3))
  rinc(2:5)=jdate(5:8)-idate(5:8)
  write(*,*) RINC   ! DAYS, HOURS, MINUTES, SECONDS, MILLISECONDS
  timediff=rinc(1)*24+rinc(2)   ! hours
  if(timediff < -49 .or. timediff > 0.1 ) then
    write(*,*) 'surface data file is too old, NO CYCLE'
    stop
  endif
!
!   cycle the surface fields
!
  call mpi_file_open(mpi_comm_world, trim(filename),     &
                     mpi_mode_rdwr,mpi_info_null, iunit, ierr)
  if (ierr /= 0) then
      call wrf_error_fatal("Error opening file with mpi io")
  end if

  call mpi_file_open(mpi_comm_world, trim(filename_sfc),     &
                    mpi_mode_rdonly,mpi_info_null, iunit_sfc, ierr)
  if (ierr /= 0) then
      call wrf_error_fatal("Error opening file with mpi io")
  end if

!  ------ cycle SMOIS
  if_integer=.false.
  VarName='SMOIS'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary_sfc629(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SNOW
  if_integer=.false.
  VarName='SNOW'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SNOWH
  if_integer=.false.
  VarName='SNOWH'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SNOWC
  if_integer=.false.
  VarName='SNOWC'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

  if( abs(timediff) < 0.01 ) then
!  ------ cycle CANWAT
     if_integer=.false.
     VarName='CANWAT'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SST   
     if_integer=.false.
     VarName='SST'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle TSLB
     if_integer=.false.
     VarName='TSLB'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary_sfc629(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SOILT1
     if_integer=.false.
     VarName='SOILT1'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle SEAICE
     if_integer=.false.
     VarName='SEAICE'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle TSK
     if_integer=.false.
     VarName='TSK'
     call mpi_barrier(mpi_comm_world,ierror)
     call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

  else

!  ------ partial cycle TSK, SOILT1, TSLB
     call mpi_barrier(mpi_comm_world,ierror)
     call partial_cycle_varaible_binary(iunit,ifswap,nrecs,iunit_sfc,nrecs_sfc, &
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc)

  endif

  if(1==2) then ! turn off because we try to initial RAPv2 from RAPv1 surface
!  ------ cycle LANDMASK
  if_integer=.false.
  VarName='LANDMASK'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &   
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle XLAND
  if_integer=.false.
  VarName='XLAND'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &   
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle LU_INDEX
  if_integer=.false.
  VarName='LU_INDEX'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &   
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle ISLTYP
  if_integer=.true.
  VarName='ISLTYP'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &   
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

!  ------ cycle IVGTYP
  if_integer=.true.
  VarName='IVGTYP'
  call mpi_barrier(mpi_comm_world,ierror)
  call full_cycle_varaible_binary(VarName,ifswap,iunit,nrecs,iunit_sfc,nrecs_sfc, &   
           varname_all,memoryorder_all,domainend_all,file_offset,      &
           varname_all_sfc,memoryorder_all_sfc,domainend_all_sfc,file_offset_sfc,if_integer)

  endif

  call mpi_file_close(iunit_sfc,ierror)

  call mpi_file_close(iunit,ierror)

  call MPI_FINALIZE(ierror)

end program full_cycle_surface_binary_mass
