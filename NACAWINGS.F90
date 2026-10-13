PROGRAM NACA_WINGS

    USE ISO_FORTRAN_ENV
    IMPLICIT NONE

    INTEGER :: IDX

    INTEGER(INT32), PARAMETER   :: N_STEPS = 10000                                       ! Computation precision

    REAL(REAL32)                :: XS(N_STEPS), YTS(N_STEPS), YCS(N_STEPS)              ! Step 1
    REAL(REAL32)                :: DYCS(N_STEPS), THETA(N_STEPS)                        ! Camber slope and angle
    REAL(REAL32)                :: XU(N_STEPS), YU(N_STEPS), XL(N_STEPS), YL(N_STEPS)   ! Airfoil surface coordinates

    REAL(REAL32)                :: T, M, P
    INTEGER(INT32)              :: NACA4, LP1, LP2, LP3     ! Left parameter #1, left parameter #2, ...

    ! Read NACA 4-digit airfoil descriptor and parse into literals
    WRITE(OUTPUT_UNIT, '(A)', ADVANCE='NO') 'Enter the 4-digit NACA airfoil number (e.g., 2412): '
    READ(INPUT_UNIT, *) NACA4
    LP1 =   NACA4 / 1000_INT32
    LP2 = ( NACA4 - LP1 * 1000_INT32 ) / 100_INT32
    LP3 =   NACA4 - LP1 * 1000_INT32 - LP2 * 100_INT32

    ! Resolve further to prepare for formula computation
    M = REAL(LP1, KIND=REAL32) / 100.0_REAL32
    P = REAL(LP2, KIND=REAL32) / 10.0_REAL32
    T = REAL(LP3, KIND=REAL32) / 100.0_REAL32

    ! Prepare indices: 0 -> 1
    XS = [(REAL(IDX - 1, KIND=REAL32) / REAL(N_STEPS - 1, KIND=REAL32), IDX = 1, N_STEPS)]

    ! Calculate wing profile
    YTS = Y_THICKNESS(XS, T)
    YCS = Y_CAMBER(XS, M, P)

    ! Write computation results to a file
    CALL SAVE_PROFILE(N_STEPS, YTS, YCS)

    ! Calculate camber slopes and angles
    DYCS = DYC_DX(XS, M, P)
    THETA = ATAN(DYCS)

    ! Calculate airfoil surface coordinates
    XU = XS  - YTS * SIN(THETA)
    YU = YCS + YTS * COS(THETA)
    XL = XS  + YTS * SIN(THETA)
    YL = YCS - YTS * COS(THETA)

    CALL SAVE_RESULTS(N_STEPS, XU, YU, XL, YL)
    
    WRITE(OUTPUT_UNIT, '(A)') 'Done.'

CONTAINS

    FUNCTION Y_THICKNESS( X, T ) RESULT( YT )

        IMPLICIT NONE

        REAL(REAL32), INTENT(IN)    :: X(:), T
        REAL(REAL32)                :: YT(SIZE(X))

        ! y_t = 5t[0.2969 \sqrt{x} - 0.1260 x - 0.3516 x^2 + 0.2843 x^3 - 0.1015 x^4]
        YT = 5.0_REAL32 * T * ( 0.2969_REAL32 * SQRT(MAX(X, 0.0_REAL32))    &
                              - 0.1260_REAL32 * X                           &
                              - 0.3516_REAL32 * (X**2)                      &
                              + 0.2843_REAL32 * (X**3)                      &
                              - 0.1015_REAL32 * (X**4))

    END FUNCTION Y_THICKNESS

    FUNCTION Y_CAMBER( X, M, P ) RESULT(YC)

        IMPLICIT NONE

        REAL(REAL32), INTENT(IN)    :: X(:), M, P
        REAL(REAL32)                :: YC(SIZE(X))

        ! Since the range of x has been assured during index construction,
        !  we no longer need to check x's range.
        ! Here, we would add an extra m and p check.
        IF (M .EQ. 0.0_REAL32 .OR. P .EQ. 0.0_REAL32) THEN
            YC = -9999.99_REAL32
            WRITE(ERROR_UNIT, *) 'Error: Invalid m or p value.'
        ELSE
            WHERE (X .LE. P)
                ! 0 <= x <= p : y_c = \frac{m}{p^2}(2px - x^2)
                YC = (M / P**2) * (2.0_REAL32 * P * X - X**2)
            ELSEWHERE
                ! p <= x <= 1 : y_c = \frac{m}{(1 - p)^2}((1 - 2p) + 2px - x^2)
                YC = (M / (1 - P)**2) &
                   * ((1.0_REAL32 - 2.0_REAL32 * P) + 2.0_REAL32 * P * X - X**2)
            END WHERE
        END IF

    END FUNCTION Y_CAMBER

    FUNCTION DYC_DX( X, M, P ) RESULT( DYCDX )

        IMPLICIT NONE

        REAL(REAL32), INTENT(IN)    :: X(:), M, P
        REAL(REAL32)                :: DYCDX(SIZE(X))

        IF (M .EQ. 0.0_REAL32 .OR. P .EQ. 0.0_REAL32) THEN
            DYCDX = -9999.99_REAL32
        ELSE
            WHERE (X .LE. P)
                DYCDX = (2.0_REAL32 * M / P**2)                * (P - X)
            ELSEWHERE
                DYCDX = (2.0_REAL32 * M / (1.0_REAL32 - P)**2) * (P - X)
            END WHERE
        END IF

    END FUNCTION DYC_DX

    SUBROUTINE SAVE_PROFILE( N_ELE, YT_ARRAY, YC_ARRAY )

        IMPLICIT NONE

        INTEGER(INT32), INTENT(IN)  :: N_ELE
        REAL(REAL32),   INTENT(IN)  :: YT_ARRAY(N_ELE), YC_ARRAY(N_ELE)
        
        INTEGER :: IOUNIT                  ! unit variable
        INTEGER :: IOSTAT                  ! I/O status code
        CHARACTER(LEN=100) :: ERRMSG       ! error message buffer

        ! Opening a file
        OPEN(NEWUNIT=IOUNIT,       &       ! NEWUNIT picks a free unit automatically
             FILE='PROFILE.DAT',   &
             STATUS='REPLACE',     &       ! REPLACE / NEW / OLD / SCRATCH / UNKNOWN
             ACTION='WRITE',       &       ! READ / WRITE / READWRITE
             IOSTAT=IOSTAT,        &       ! 0 = success, >0 = error
             IOMSG=ERRMSG)                 ! human-readable error text

        ! Check if file is successfully configured for further access
        IF (IOSTAT .NE. 0) THEN
            WRITE(ERROR_UNIT, *) 'Open failed: ', TRIM(ERRMSG)
            STOP 1
        END IF

        ! Parameter of the airfoil
        ! WRITE(IOUNIT, '(A32, I8)')      'NACA 4-digit identifier:',     NACA4
        WRITE(IOUNIT, '(A27, I8, A2)')  'Maximum camber percentage :',  LP1     , '%'
        WRITE(IOUNIT, '(A27, I8, A2)')  'Maximum camber location   :',  LP2     , '%'
        WRITE(IOUNIT, '(A27, I8, A15)') 'Camber thickness          :',  LP3     , '% of the chord'
        WRITE(IOUNIT, *)

        ! Header
        WRITE(IOUNIT, '(3A14)') 'X', 'YC', 'YT'
        WRITE(IOUNIT, '(A)')    REPEAT('-', 42)

        ! Write data into the file line-by-line
        DO IDX = 1, N_ELE
            WRITE(IOUNIT, '(3F14.10)') &
                  REAL(IDX - 1, KIND=REAL32) / REAL(N_ELE - 1, KIND=REAL32), YT_ARRAY(IDX), YC_ARRAY(IDX)
        END DO

        ! Highly recommended: close file handle after use
        CLOSE(IOUNIT)

    END SUBROUTINE SAVE_PROFILE

    SUBROUTINE SAVE_RESULTS( N_ELE, XU, YU, XL, YL )

        IMPLICIT NONE

        INTEGER(INT32), INTENT(IN)  :: N_ELE
        REAL(REAL32), INTENT(IN)    :: XU(N_ELE), YU(N_ELE), XL(N_ELE), YL(N_ELE)

        INTEGER :: IOUNIT                  ! unit variable
        INTEGER :: IOSTAT                  ! I/O status code
        CHARACTER(LEN=100) :: ERRMSG       ! error message buffer

        ! Opening a file
        OPEN(NEWUNIT=IOUNIT,       &       ! NEWUNIT picks a free unit automatically
             FILE='RESULTS.DAT',   &
             STATUS='REPLACE',     &       ! REPLACE / NEW / OLD / SCRATCH / UNKNOWN
             ACTION='WRITE',       &       ! READ / WRITE / READWRITE
             IOSTAT=IOSTAT,        &       ! 0 = success, >0 = error
             IOMSG=ERRMSG)                 ! human-readable error text

        ! Check if file is successfully configured for further access
        IF (IOSTAT .NE. 0) THEN
            WRITE(ERROR_UNIT, *) 'Open failed: ', TRIM(ERRMSG)
            STOP 1
        END IF

        ! Header
        WRITE(IOUNIT, '(4A14)') 'XU', 'YU', 'XL', 'YL'
        WRITE(IOUNIT, '(A)')    REPEAT('-', 56)

        ! Data — all four columns per row
        DO IDX = 1, N_ELE
            WRITE(IOUNIT, '(4F14.10)') &
                  XU(IDX), YU(IDX), XL(IDX), YL(IDX)
        END DO

        ! Highly recommended: close file handle after use
        CLOSE(IOUNIT)

    END SUBROUTINE SAVE_RESULTS

END PROGRAM NACA_WINGS
