function [LL,XX,E] = equib(T,A,alpha,alpha_h,M,N,L,theta,s,W1)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Outputs:                          %
% LL: labour share in each industry %
% XX: simulated trade flow data     %
% E: total expenditure              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%calculate the countries expenditure : refer to note May_22
pi = zeros(N,N,M);
temp = zeros(N,N,M);
for i = 1:N
    for j = 1:N
        for r = 1:M
            temp(i,j,r) = (T(i,j,r)/A(i,r)).^(-theta);
        end
    end
end

temp2 = sum(temp,1);
for r = 1:M
    pi(:,:,r) = temp(:,:,r)./repmat(temp2(:,:,r),N,1);
end

phi = zeros(N,N,M);
for i = 1:N
    for j = 1:N
        for r = 1:M
            phi(i,j,r) = pi(i,j,r)*alpha(j,r)*(1-alpha_h(j));
        end
    end
end

Omega = zeros(N,N);
s1 = 0;
Omega = zeros(N,N);
for i = 1:N
    for j = 1:N
        temp1 = reshape(phi(i,j,:),1,M);
        temp2 = reshape(phi(1,j,:),1,M);
        Omega(i,j) = temp2*(s1-s)-L(1)/L(i)*temp1*(s1-s);
    end
end

F = diag(L(1)./L(2:N)*(1-s1))-Omega(2:N,2:N);
G = (1-s1)+Omega(2:N,1);
E = F\G;
E = [W1;W1*E];

%output: bilateral trade flows
XX = zeros(N,N,M);
for i = 1:N
    for j = 1:N
        for r = 1:M
            XX(i,j,r) = pi(i,j,r)*alpha(j,r)*(1-alpha_h(j))*E(j);
        end
    end
end


%output: exports of homo goods
exp_h = E-sum(sum(XX,3),2);
for i = 1:N
    if exp_h(i)<0
        disp ('error: negative production in homo. sector')
    end
end

%wage
temp = sum(XX,2);
temp = reshape(temp(:),N,M);
w1 = ((1-s1)*exp_h+temp*(1-s))./L;

%employment in each diff. sector
LL = zeros(N,M);
for i = 1:N
    for r = 1:M
        LL(i,r) = (1-s(r))*temp(i,r)/w1(1);
    end
end

LL = LL./repmat(L,1,M); %output employment weight

norm = W1/w1(1);
E = E.*norm;
XX=XX.*norm;


