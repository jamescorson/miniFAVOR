!  miniFAVOR.f90
!
!  FUNCTIONS:
!  miniFAVOR - Entry point of console application.
!

!****************************************************************************
!
!  PROGRAM: miniFAVOR
!
!  PURPOSE:  Entry point for the console application.
!
!****************************************************************************

    program miniFAVOR

    use I_O, only : read_In, write_Out
    use calc_RTndt, only : RTndt, CF, sample_chem
    use calc_K, only : Ki_t
    use calc_cpi, only : cpi_t
    use randomness_m, only: random_samples_t

    implicit none

    ! Variables
    character(len=64) :: fn_IN
    integer, parameter :: n_IN = 15
    integer, parameter :: n_ECHO = n_IN + 1
    integer, parameter :: n_OUT = n_IN + 2
    integer, parameter :: n_DAT = n_IN + 3
    integer :: i, j, num_seeds
    type(random_samples_t), allocatable :: samples(:)

    ! Inputs
    real :: a, b
    integer :: nsim, ntime
    logical :: details
    real, dimension(:), allocatable :: stress, temp
    real :: Cu_ave, Ni_ave, Cu_sig, Ni_sig, fsurf, RTndt0

    ! Outputs
    real, allocatable :: K_hist(:)
    real, allocatable :: Chemistry_factor(:)
    real, allocatable :: R_Tndt(:)
    real, allocatable :: CPI(:)
    real, allocatable :: CPI_avg(:)
    real, dimension(:,:), allocatable :: Chemistry_content
    real, dimension(:,:), allocatable :: cpi_hist
    integer, parameter :: nmaterials=2

    ! Body of miniFAVOR

    !Get input file name
    call random_seed(size=num_seeds)
    call random_seed(put=[(i, i=1, num_seeds)])

    print *, 'Input file name:'
    read (*,'(a)') fn_IN

    !Read input file
    call read_IN(fn_IN, n_IN, n_ECHO, &
        a, b, nsim, ntime, details, Cu_ave, Ni_ave, Cu_sig, Ni_sig, fsurf, RTndt0, stress, temp)

    !Allocate output arrays
    allocate(Chemistry_content(nsim, nmaterials))
    allocate(Chemistry_factor(nsim))
    allocate(cpi_hist(nsim, ntime))
    allocate(R_Tndt(nsim), CPI(nsim), CPI_avg(nsim), samples(nsim))

    !Calculate applied stress intensity factor (SIF)
    K_hist = Ki_t(a, b, stress)

    ! This cannot be parallelized or reordered without the results changing
    do i = 1, nsim
      call samples(i)%define()
    end do

    !Start looping over number of simulations
    Vessel_loop: do i = 1, nsim

        !Sample chemistry: Chemistry_content(i,1) is Cu content, Chemistry_content(i,2) is Ni content
        call sample_chem(Cu_ave, Ni_ave, Cu_sig, Ni_sig, Chemistry_content(i,1), Chemistry_content(i,2), samples(i))

        !Calculate chemistry factor: Chemistry_factor(i) is chemistry factor
        Chemistry_factor(i) = CF(Chemistry_content(i,1), Chemistry_content(i,2))

        !Calculate RTndt for this vessel trial: CPI_results(i,1) is RTndt
        R_Tndt(i) = RTndt(a, Chemistry_factor(i), fsurf, RTndt0, samples(i)%phi())

        !Start time loop
        Time_loop: do j = 1, ntime
            !Calculate instantaneous cpi(t)
            cpi_hist(i,j) = cpi_t(K_hist(j), R_Tndt(i), temp(j))
        end do Time_loop

        !Calculate CPI for vessel 'i'
        CPI(i) = maxval(cpi_hist(i,:))

        !Calculate moving average CPI for trials executed so far
        CPI_avg(i) = sum(CPI(1:i))/i

    end do Vessel_loop

    call write_OUT(fn_IN, n_OUT, n_DAT, &
        a, b, nsim, ntime, details, Cu_ave, Ni_ave, Cu_sig, Ni_sig, fsurf, RTndt0, &
        R_Tndt, CPI, CPI_avg, K_hist, Chemistry_content, Chemistry_factor)

    end program miniFAVOR
