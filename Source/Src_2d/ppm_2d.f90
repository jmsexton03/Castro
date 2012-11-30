      ! characteristics based on u
      subroutine ppm(s,qd_l1,qd_l2,qd_h1,qd_h2,u,cspd,Ip,Im,ilo1,ilo2,ihi1,ihi2,dx,dy,dt)

        use meth_params_module, only : ppm_type

        implicit none

        integer          qd_l1,qd_l2,qd_h1,qd_h2
        integer          ilo1,ilo2,ihi1,ihi2
        double precision s(qd_l1:qd_h1,qd_l2:qd_h2)
        double precision u(qd_l1:qd_h1,qd_l2:qd_h2,1:2)
        double precision cspd(qd_l1:qd_h1,qd_l2:qd_h2)
        double precision Ip(ilo1-1:ihi1+1,ilo2-1:ihi2+1,1:2,1:3)
        double precision Im(ilo1-1:ihi1+1,ilo2-1:ihi2+1,1:2,1:3)
        double precision dx,dy,dt

        ! local
        integer i,j

        logical extremum, bigp, bigm

        double precision dsl, dsr, dsc, D2, D2C, D2L, D2R, D2LIM, C, alphap, alpham
        double precision sgn, sigma, s6, amax, delam, delap
        double precision dafacem, dafacep, dabarm, dabarp, dafacemin, dabarmin
        double precision dachkm, dachkp

        ! s_{\ib,+}, s_{\ib,-}
        double precision, allocatable :: sp(:,:)
        double precision, allocatable :: sm(:,:)

        ! \delta s_{\ib}^{vL}
        double precision, allocatable :: dsvl(:,:)

        ! s_{i+\half}^{H.O.}
        double precision, allocatable :: sedge(:,:)

        ! cell-centered indexing
        allocate(sp(ilo1-1:ihi1+1,ilo2-1:ihi2+1))
        allocate(sm(ilo1-1:ihi1+1,ilo2-1:ihi2+1))

        ! constant used in Colella 2008
        C = 1.25d0

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ! x-direction
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ! cell-centered indexing w/extra x-ghost cell
        allocate(dsvl(ilo1-2:ihi1+2,ilo2-1:ihi2+1))

        ! edge-centered indexing for x-faces
        if (ppm_type .eq. 1) then
           allocate(sedge(ilo1-1:ihi1+2,ilo2-1:ihi2+1))
        else
           allocate(sedge(ilo1-2:ihi1+3,ilo2-1:ihi2+1))
        end if
        
        ! compute s at x-edges
        if (ppm_type .eq. 1) then

           ! compute van Leer slopes in x-direction
           dsvl = 0.d0
           do j=ilo2-1,ihi2+1
              do i=ilo1-2,ihi1+2
                 dsc = 0.5d0 * (s(i+1,j) - s(i-1,j))
                 dsl = 2.d0  * (s(i  ,j) - s(i-1,j))
                 dsr = 2.d0  * (s(i+1,j) - s(i  ,j))
                 if (dsl*dsr .gt. 0.d0) &
                      dsvl(i,j) = sign(1.d0,dsc)*min(abs(dsc),abs(dsl),abs(dsr))
              end do
           end do

           ! interpolate s to x-edges
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+2
                 sedge(i,j) = 0.5d0*(s(i,j)+s(i-1,j)) - (1.d0/6.d0)*(dsvl(i,j)-dsvl(i-1,j))
                 ! make sure sedge lies in between adjacent cell-centered values
                 sedge(i,j) = max(sedge(i,j),min(s(i,j),s(i-1,j)))
                 sedge(i,j) = min(sedge(i,j),max(s(i,j),s(i-1,j)))
              end do
           end do

           ! copy sedge into sp and sm
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1
                 sp(i,j) = sedge(i+1,j)
                 sm(i,j) = sedge(i  ,j)
              end do
           end do

           ! modify using quadratic limiters
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1
                 if ((sp(i,j)-s(i,j))*(s(i,j)-sm(i,j)) .le. 0.d0) then
                    sp(i,j) = s(i,j)
                    sm(i,j) = s(i,j)
                 else if (abs(sp(i,j)-s(i,j)) .ge. 2.d0*abs(sm(i,j)-s(i,j))) then
                    sp(i,j) = 3.d0*s(i,j) - 2.d0*sm(i,j)
                 else if (abs(sm(i,j)-s(i,j)) .ge. 2.d0*abs(sp(i,j)-s(i,j))) then
                    sm(i,j) = 3.d0*s(i,j) - 2.d0*sp(i,j)
                 end if
              end do
           end do

        else if (ppm_type .eq. 2) then

           ! interpolate s to x-edges
           do j=ilo2-1,ihi2+1
              do i=ilo1-2,ihi1+3
                 sedge(i,j) = (7.d0/12.d0)*(s(i-1,j)+s(i,j)) - (1.d0/12.d0)*(s(i-2,j)+s(i+1,j))
                 ! limit sedge
                 if ((sedge(i,j)-s(i-1,j))*(s(i,j)-sedge(i,j)) .lt. 0.d0) then
                    D2  = 3.d0*(s(i-1,j)-2.d0*sedge(i,j)+s(i,j))
                    D2L = s(i-2,j)-2.d0*s(i-1,j)+s(i,j)
                    D2R = s(i-1,j)-2.d0*s(i,j)+s(i+1,j)
                    sgn = sign(1.d0,D2)
                    D2LIM = sgn*max(min(C*sgn*D2L,C*sgn*D2R,sgn*D2),0.d0)
                    sedge(i,j) = 0.5d0*(s(i-1,j)+s(i,j)) - (1.d0/6.d0)*D2LIM
                 end if
              end do
           end do

           ! use Colella 2008 limiters
           ! This is a new version of the algorithm 
           ! to eliminate sensitivity to roundoff.
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1

                 alphap = sedge(i+1,j)-s(i,j)
                 alpham = sedge(i  ,j)-s(i,j)
                 bigp = abs(alphap).gt.2.d0*abs(alpham)
                 bigm = abs(alpham).gt.2.d0*abs(alphap)
                 extremum = .false.

                 if (alpham*alphap .ge. 0.d0) then
                    extremum = .true.
                 else if (bigp .or. bigm) then
                    ! Possible extremum. We look at cell centered values and face
                    ! centered values for a change in sign in the differences adjacent to
                    ! the cell. We use the pair of differences whose minimum magnitude is the
                    ! largest, and thus least susceptible to sensitivity to roundoff.
                    dafacem = sedge(i,j) - sedge(i-1,j)
                    dafacep = sedge(i+2,j) - sedge(i+1,j)
                    dabarm = s(i,j) - s(i-1,j)
                    dabarp = s(i+1,j) - s(i,j)
                    dafacemin = min(abs(dafacem),abs(dafacep))
                    dabarmin= min(abs(dabarm),abs(dabarp))
                    if (dafacemin.ge.dabarmin) then
                       dachkm = dafacem
                       dachkp = dafacep
                    else
                       dachkm = dabarm
                       dachkp = dabarp
                    endif
                    extremum = (dachkm*dachkp .le. 0.d0)
                 end if

                 if (extremum) then
                    D2  = 6.d0*(alpham + alphap)
                    D2L = s(i-2,j)-2.d0*s(i-1,j)+s(i,j)
                    D2R = s(i,j)-2.d0*s(i+1,j)+s(i+2,j)
                    D2C = s(i-1,j)-2.d0*s(i,j)+s(i+1,j)
                    sgn = sign(1.d0,D2)
                    D2LIM = max(min(sgn*D2,C*sgn*D2L,C*sgn*D2R,C*sgn*D2C),0.d0)
                    alpham = alpham*D2LIM/max(abs(D2),1.d-10)
                    alphap = alphap*D2LIM/max(abs(D2),1.d-10)
                 else
                    if (bigp) then
                       sgn = sign(1.d0,alpham)
                       amax = -alphap**2 / (4*(alpham + alphap))
                       delam = s(i-1,j) - s(i,j)
                       if (sgn*amax .ge. sgn*delam) then
                          if (sgn*(delam - alpham).ge.1.d-10) then
                             alphap = (-2.d0*delam - 2.d0*sgn*sqrt(delam**2 - delam*alpham))
                          else 
                             alphap = -2.d0*alpham
                          endif
                       endif
                    end if
                    if (bigm) then
                       sgn = sign(1.d0,alphap)
                       amax = -alpham**2 / (4*(alpham + alphap))
                       delap = s(i+1,j) - s(i,j)
                       if (sgn*amax .ge. sgn*delap) then
                          if (sgn*(delap - alphap).ge.1.d-10) then
                             alpham = (-2.d0*delap - 2.d0*sgn*sqrt(delap**2 - delap*alphap))
                          else
                             alpham = -2.d0*alphap
                          endif
                       endif
                    end if
                 end if

                 sm(i,j) = s(i,j) + alpham
                 sp(i,j) = s(i,j) + alphap

              end do
           end do

        end if

       ! compute x-component of Ip and Im
        do j=ilo2-1,ihi2+1
           do i=ilo1-1,ihi1+1
              s6 = 6.0d0*s(i,j) - 3.0d0*(sm(i,j)+sp(i,j))
              sigma = abs(u(i,j,1)-cspd(i,j))*dt/dx
              Ip(i,j,1,1) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,1,1) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              sigma = abs(u(i,j,1))*dt/dx
              Ip(i,j,1,2) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,1,2) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              sigma = abs(u(i,j,1)+cspd(i,j))*dt/dx
              Ip(i,j,1,3) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,1,3) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
           end do
        end do

        deallocate(sedge,dsvl)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ! y-direction
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ! cell-centered indexing w/extra y-ghost cell
        allocate( dsvl(ilo1-1:ihi1+1,ilo2-2:ihi2+2))

        ! edge-centered indexing for y-faces
        if (ppm_type .eq. 1) then
           allocate(sedge(ilo1-1:ihi1+1,ilo2-1:ihi2+2))
        else
           allocate(sedge(ilo1-1:ihi1+1,ilo2-2:ihi2+3))
        end if

        ! compute s at y-edges
        if (ppm_type .eq. 1) then

           ! compute van Leer slopes in y-direction
           dsvl = 0.d0
           do j=ilo2-2,ihi2+2
              do i=ilo1-1,ihi1+1
                 dsc = 0.5d0 * (s(i,j+1) - s(i,j-1))
                 dsl = 2.d0  * (s(i,j  ) - s(i,j-1))
                 dsr = 2.d0  * (s(i,j+1) - s(i,j  ))
                 if (dsl*dsr .gt. 0.d0) &
                      dsvl(i,j) = sign(1.d0,dsc)*min(abs(dsc),abs(dsl),abs(dsr))
              end do
           end do

           ! interpolate s to y-edges
           do j=ilo2-1,ihi2+2
              do i=ilo1-1,ihi1+1
                 sedge(i,j) = 0.5d0*(s(i,j)+s(i,j-1)) - (1.d0/6.d0)*(dsvl(i,j)-dsvl(i,j-1))
                 ! make sure sedge lies in between adjacent cell-centered values
                 sedge(i,j) = max(sedge(i,j),min(s(i,j),s(i,j-1)))
                 sedge(i,j) = min(sedge(i,j),max(s(i,j),s(i,j-1)))
              end do
           end do

           ! copy sedge into sp and sm
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1
                 sp(i,j) = sedge(i,j+1)
                 sm(i,j) = sedge(i,j  )
              end do
           end do

           ! modify using quadratic limiters
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1
                 if ((sp(i,j)-s(i,j))*(s(i,j)-sm(i,j)) .le. 0.d0) then
                    sp(i,j) = s(i,j)
                    sm(i,j) = s(i,j)
                 else if (abs(sp(i,j)-s(i,j)) .ge. 2.d0*abs(sm(i,j)-s(i,j))) then
                    sp(i,j) = 3.d0*s(i,j) - 2.d0*sm(i,j)
                 else if (abs(sm(i,j)-s(i,j)) .ge. 2.d0*abs(sp(i,j)-s(i,j))) then
                    sm(i,j) = 3.d0*s(i,j) - 2.d0*sp(i,j)
                 end if
              end do
           end do

        else if (ppm_type .eq. 2) then

           ! interpolate s to y-edges
           do j=ilo2-2,ihi2+3
              do i=ilo1-1,ihi1+1
                 sedge(i,j) = (7.d0/12.d0)*(s(i,j-1)+s(i,j)) - (1.d0/12.d0)*(s(i,j-2)+s(i,j+1))
                 ! limit sedge
                 if ((sedge(i,j)-s(i,j-1))*(s(i,j)-sedge(i,j)) .lt. 0.d0) then
                    D2  = 3.d0*(s(i,j-1)-2.d0*sedge(i,j)+s(i,j))
                    D2L = s(i,j-2)-2.d0*s(i,j-1)+s(i,j)
                    D2R = s(i,j-1)-2.d0*s(i,j)+s(i,j+1)
                    sgn = sign(1.d0,D2)
                    D2LIM = sgn*max(min(C*sgn*D2L,C*sgn*D2R,sgn*D2),0.d0)
                    sedge(i,j) = 0.5d0*(s(i,j-1)+s(i,j)) - (1.d0/6.d0)*D2LIM
                 end if
              end do
           end do

           ! use Colella 2008 limiters
           ! This is a new version of the algorithm 
           ! to eliminate sensitivity to roundoff.
           do j=ilo2-1,ihi2+1
              do i=ilo1-1,ihi1+1

                 alphap = sedge(i,j+1)-s(i,j)
                 alpham = sedge(i,j  )-s(i,j)
                 bigp = abs(alphap).gt.2.d0*abs(alpham)
                 bigm = abs(alpham).gt.2.d0*abs(alphap)
                 extremum = .false.

                 if (alpham*alphap .ge. 0.d0) then
                    extremum = .true.
                 else if (bigp .or. bigm) then
                    ! Possible extremum. We look at cell centered values and face
                    ! centered values for a change in sign in the differences adjacent to
                    ! the cell. We use the pair of differences whose minimum magnitude is the
                    ! largest, and thus least susceptible to sensitivity to roundoff.
                    dafacem = sedge(i,j) - sedge(i,j-1)
                    dafacep = sedge(i,j+2) - sedge(i,j+1)
                    dabarm = s(i,j) - s(i,j-1)
                    dabarp = s(i,j+1) - s(i,j)
                    dafacemin = min(abs(dafacem),abs(dafacep))
                    dabarmin= min(abs(dabarm),abs(dabarp))
                    if (dafacemin.ge.dabarmin) then
                       dachkm = dafacem
                       dachkp = dafacep
                    else
                       dachkm = dabarm
                       dachkp = dabarp
                    endif
                    extremum = (dachkm*dachkp .le. 0.d0)
                 end if

                 if (extremum) then
                    D2  = 6.d0*(alpham + alphap)
                    D2L = s(i,j-2)-2.d0*s(i,j-1)+s(i,j)
                    D2R = s(i,j)-2.d0*s(i,j+1)+s(i,j+2)
                    D2C = s(i,j-1)-2.d0*s(i,j)+s(i,j+1)
                    sgn = sign(1.d0,D2)
                    D2LIM = max(min(sgn*D2,C*sgn*D2L,C*sgn*D2R,C*sgn*D2C),0.d0)
                    alpham = alpham*D2LIM/max(abs(D2),1.d-10)
                    alphap = alphap*D2LIM/max(abs(D2),1.d-10)
                 else
                    if (bigp) then
                       sgn = sign(1.d0,alpham)
                       amax = -alphap**2 / (4*(alpham + alphap))
                       delam = s(i,j-1) - s(i,j)
                       if (sgn*amax .ge. sgn*delam) then
                          if (sgn*(delam - alpham).ge.1.d-10) then
                             alphap = (-2.d0*delam - 2.d0*sgn*sqrt(delam**2 - delam*alpham))
                          else 
                             alphap = -2.d0*alpham
                          endif
                       endif
                    end if
                    if (bigm) then
                       sgn = sign(1.d0,alphap)
                       amax = -alpham**2 / (4*(alpham + alphap))
                       delap = s(i,j+1) - s(i,j)
                       if (sgn*amax .ge. sgn*delap) then
                          if (sgn*(delap - alphap).ge.1.d-10) then
                             alpham = (-2.d0*delap - 2.d0*sgn*sqrt(delap**2 - delap*alphap))
                          else
                             alpham = -2.d0*alphap
                          endif
                       endif
                    end if
                 end if

                 sm(i,j) = s(i,j) + alpham
                 sp(i,j) = s(i,j) + alphap

              end do
           end do

        end if

        ! compute y-component of Ip and Im
        do j=ilo2-1,ihi2+1
           do i=ilo1-1,ihi1+1
              s6 = 6.0d0*s(i,j) - 3.0d0*(sm(i,j)+sp(i,j))
              sigma = abs(u(i,j,2)-cspd(i,j))*dt/dy
              Ip(i,j,2,1) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,2,1) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              sigma = abs(u(i,j,2))*dt/dy
              Ip(i,j,2,2) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,2,2) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              sigma = abs(u(i,j,2)+cspd(i,j))*dt/dy
              Ip(i,j,2,3) = sp(i,j) - &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)-(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
              Im(i,j,2,3) = sm(i,j) + &
                   (sigma/2.0d0)*(sp(i,j)-sm(i,j)+(1.0d0-(2.0d0/3.0d0)*sigma)*s6)
           end do
        end do

        deallocate(sp,sm,dsvl,sedge)
        
      end subroutine ppm
