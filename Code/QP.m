%% Clean up
close all
clear;
clc;
warning off;

%% Generate starting points

xmin = -10;
xmax = 10;
%for iter = 1:10

x=zeros(1,3);
startX  = 6.0; %xmin + rand(1) * (xmax-xmin); %8.0;
startY  = -4.0; %xmin + rand(1) * (xmax-xmin); %-9.0;
phi     = 0;
goalX   = -3;
goalY   = -1;

% Make this egocentric
startX  = startX;% - goalX;
startY  = startY;% - goalY;

%% Initialize the values
% Transform from cartesian to polar co-ordinates
% r         = sqrt(x^2 + y^2);
% theta     = -atan2(y,x) + phi + pi
% delta     = gamma - phi

nx   = startX;
ny   = startY;
nt   = phi;

x(1)=sqrt(startX^2+startY^2);
x(3)=wrapToPi(pi - atan2(startY,startX) + phi) ;
x(2)=wrapToPi(- phi+ x(3));

%% Plot the start and the end state
r=0.5;
ang=0:0.01:2*pi; 
xp=r*cos(ang);
yp=r*sin(ang);
figure(1);
hold on;
plot(startX+xp,startY+yp,'r',[startX startX+r*cos(phi)],[startY startY+r*sin(phi)],'r','Linewidth',1.5)
hold on
plot(xp,yp,'b',[0 r],[0 0],'b','Linewidth',1.5)

axis([-10 14 -10 14])
hold on

%% Initialize the values and storage variables
dT      = 0.01;
R       = [x(1)];
X       = [startX];
Y       = [startY];
Theta   = [];
Q       = diag([1, 0.1]);
delta   = [];
U1      = [];
U2      = [];
Slk     = [];
Slk2    = [];
NX      = [nx];
NY      = [ny];
k1      = 1;
k2      = 1;


%% Iterate over to find the optimal control
for i = 1:1800
if x(1) < 1e-1
    break;
end

tic();
cvx_begin quiet
        cvx_solver sedumi
        variable u(6);
        minimize( u(1:4).' * u(1:4) + 10 * u(6) + 1 * u(5));
        subject to
            % Lyapunov function used:
            % V    = 0.5 * (r^2 + theta^2)
            % Derivative of V
            % Vdot = r*r_dot + theta*theta_dot
            %      = -r*v*cos(arctan(-k1*theta)) + (v/r) * theta *
            %      sin(arctan(-k1 * theta)
            
            %-(x(1)) * u(1) * cos(atan(-k1*x(2))) <= ...
            %    0.5 * u(6) * ((x(1))^2 ) + u(3);

            -(x(1)) * u(1) * cos(atan(-k1*x(2))) + (x(2)) * u(1)/x(1) * sin(atan(-k1*x(2))) <= ...
                0.5 * u(6) * ((x(1))^2 + (x(2))^2) + u(3);
            u(6) <= 0.0;

            % Define the obstacle in egocentric view:
            % hdot = 1/h * ((sin(x(2)) * x(1) - b_y) + cos(x(2)) * (cos(x(2)*x + b_x)) ) 
            
            b_x     = -1.42;
            b_y     = -2.16;
            h       = sqrt( (-x(1)*cos(x(2)) - b_x) ^2 + (x(1) * sin(x(2)) - b_y) ^2);
            if (h < 0.8)
                hdot    = 1/h * (x(1) - b_y * sin(x(2)) + b_x * cos(x(2))) * -u(1) * cos(x(3)) + ...
                    -1/h * x(1) * (b_x * sin(x(2)) + b_y * cos(x(2)) ) * u(1)/x(1) * sin(x(3)) ;
                
                hdot  <= u(5) * h + u(3);
                u(5)  <= 0.0;
                B       = 1 / (h - 0.3);
                Bdot    = - hdot / (h - 0.3)^2;
                Bdot    <= 1.0/B;
                z        = x(3) - atan(k1 *(atan2((x(1)*sin(x(2)) - b_y), (-x(1) * cos(x(2)) - b_x)) ));
                zdot     = u(1)/ x(1) * sin(k1 * x(3)) + u(2);
                z * zdot <= -0.5 * k2 * z^2 + u(4);
            else
                z        = x(3) - atan(-k1 * x(2));
                zdot     = ((1 + 1/ (1 + x(2)^2) ) * u(1) / x(1) * sin(z + atan(-k1 * x(2))) + u(2));
                
                z * zdot <= -0.5 * k2 * z^2 + u(4);
                u(5) == 0;
            end
            %u(5) <= 0.0;
            
            -1.0 <= u(2) <= 1.0;
            0.0  <= u(1) <= 2.0;
cvx_end
toc();

% Fixed control works
% u(1)= x(1);
% u(2)= -u(1)/x(1) *( ( k2*(x(3)-atan(-k1*x(2))) )  +  ( 1 + k1 / (1+( k1 * x(2) )^2) *sin(x(3)) ) );


%% Smoothen the control
if size(U1,1) > 1
    u(1) = 0.85 * U1(end) + 0.15 * u(1);
    u(2) = 0.85 * U2(end) + 0.15 * u(2);
end

%% Propogate with dynamics
x(1) = x(1) - dT * u(1) * cos(x(3)); % + 0.5 * (u(1)/x(1) * sin(x(3))) + u(2));
x(2) = x(2) + dT * u(1)/x(1) * sin(x(3)); % + 0.5 * (u(1)/x(1) * sin(x(3))) + u(2));
x(3) = x(3) + dT * (u(1)/x(1) * sin(x(3)) + u(2))  ;
x(3) = wrapToPi(x(3));
x(2) = wrapToPi(x(2));

nx   = nx + dT * u(1) * cos(nt + u(2)*dT/2);
ny   = ny + dT * u(1) * sin(nt + u(2)*dT/2);
nt   = nt + dT * u(2);

%% Store the variables
R=[R;x(1)];
Theta=[Theta;x(2)];
delta=[delta;x(3)];
X=[X; -x(1)*cos(x(2))];
Y=[Y; x(1)*sin(x(2))];
U1=[U1;u(1)];
U2=[U2;u(2)];
Slk = [Slk;u(3)];
Slk2= [Slk2;u(4)];
NX  = [NX; nx];
NY  = [NY; ny];
end

%% Generate plots
hold on;
figure(1); plot(X,Y); title('Trajectory'); plot(b_x,b_y, 'o')
figure(2); plot(NX, NY);
% figure(2); plot(R); title('Distance to go')
% figure(3); plot(Theta); title('Theta')
% figure(4); plot(delta); title('Delta')
figure(5); plot(U1); title('U1')
figure(6); plot(U2); title('U2')
figure(7); plot(Slk); title('Slk')
figure(8); plot(Slk2); title('Slk2');
%end

warning on;
