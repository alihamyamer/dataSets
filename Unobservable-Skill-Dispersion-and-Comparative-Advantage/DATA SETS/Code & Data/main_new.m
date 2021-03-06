clc
clear

cd ('/Users/li/Dropbox/Skilldisp/Ruoying&Crystal/new model/temp_lambdas/Codes and Data'); %directory subject to change

load 'X1.mat' %bilateral trade flows from the data
load 'alpha.mat' %consumption share in diff. sectors from data: calibrated from wage dispersion (less than 1)
load 'scores.mat'  %skill data: raw data with a normalization
load 'nrescore.mat'  %skill data: residual data with a normalization
load 'W.mat'  %weights of skill: raw data with a normalization
load 'W_n.mat' %weights of skill: residual data with a normalization
load 'L.mat'  %population
load 'lambda_new' %lambda's calirated using gamma=0.3,0.5&0.7

countries(1,:) = []; %remove the header of the country list
countries(4,:) = []; %remove Chile from the country list

N = 18; %number of countries
M = 63; %number of industries
theta = 6.53; %theta from Costinot et.al (2012)

%Case I%
gamma = 0.3;
lambda = lambda_new(:,1); %lambda's calibrated using total compensation and gamma=0.3

%Case II%
%gamma = 0.5;
%ambda = lambda_new(:,3); %lambda's calibrated using total compensation and gamma=0.5

%Case III%
%gamma = 0.7;
%lambda = lambda_new(:,5); %lambda's calibrated using total compensation and gamma=0.7


X(X==0)=1; %if the trade flow is equal to 0, set to 1

s = zeros(M,1); 
s1 = 0;

A = TFP_A(lambda,nscore,W,gamma); %compute A's using normalized raw score data
A_n = TFP_A(lambda,nrescore,W_n,gamma); %compute A's using normalized residual score data

%A = A_n; % for the case if want to do the simulation and experiments using the A's from the residual score data

% caculate the variance of "log_a" and "a"
v_loga = zeros(N,1);  
v_a = zeros(N,1);
temp = zeros(N+1,1);
temp3 = zeros(N+1,1);
for i = 1:N+1
    %temp1 = nscore(i,:);
    %temp2 = W(i,:);
    temp1 = nrescore(i,:);
    temp2 = W_n(i,:);
    a = temp1(isfinite(temp1));
    weight = temp2(isfinite(temp1)); 
    temp(i) = var(log(a),weight);
    temp3(i) = var(a,weight);    
end

v_loga(1:3,:) = temp(1:3,:); % the data fo Chile needs to be removed
v_loga(4:N,:) = temp(5:N+1,:);
v_a(1:3,:) = temp3(1:3,:); % the data fo Chile needs to be removed
v_a(4:N,:) = temp3(5:N+1,:);

%%%%%%%%%%%%%%%%%%%%%%%%%
% Benchmark Calibration %
%%%%%%%%%%%%%%%%%%%%%%%%%

%Total expenditure in the diff. sectors%
E0 = zeros(N,1);
for i = 1:N
    E0(i) = sum(sum(X(:,i,:)));
end

%Calibtraion of the Iceberg Costs tau's
%Details of the procedure can be found in the Appendix of the paper

%Step 1: estimated tau's using the relative trade flows 
pi = zeros(N,N,M); 
temp = sum(X,1);
for r = 1:M
    pi(:,:,r) = X(:,:,r)./repmat(temp(:,:,r),N,1);
end

T = zeros(N,N,M); 
for i = 1:N
    for j = 1:N
        for r = 1:M
            T(i,j,r) = pi(i,j,r)^(-1/theta)*A(i,r);
        end
    end
end

for i = 1:N
    for r = 1:M
        T(:,i,r) = T(:,i,r)./T(i,i,r); %step 1 estimated tau's
    end
end

%Step 2:Removing the comparative advantage introduced by tau's by decomposing step 1 estimated tau's into (1) a common country pair component and (2) a country-industry specic term
%The docomposition is carried out using OLS regression

log_T = zeros(N-1,N,M);
for i = 1:M
    temp = T(:,:,i);
    temp(logical(eye(size(temp)))) = []; %removing the diagonal term from the step 1 esimated tau's so that the matrix of log_T is of dimension N-1*N*M
    temp = reshape(temp,N-1,N);
    log_T(:,:,i) = log(temp); %taking logs 
end

log_T = log_T(:); %vectorize log_T and make it the dependent variable in the OLS regression

I_i_j = repmat(eye(N*(N-1),N*(N-1)),M,1); %dummy variables indicating the common country pair component
I_j_lambda = kron(eye(M,M),kron(eye(N,N),ones(N-1,1))); %dummy variables indicating country-industry specic term

Y = log_T; %dependent variable
Z = [I_i_j,I_j_lambda(:,19:end)]; %independent variable: the first 18 columns of I_j_lambda is removed because of the multicollinearity
b = inv(Z'*Z)*Z'*Y; %OLS estimates

e = Y-Z*b; %residual term
Adjust_R2 = 1-var(e,1)/var(Y,1)*(size(Z,1)-1)/(size(Z,1)-size(Z,2)-1); %adjusted R-squared

TT = exp(Z*b); %fitted values (the off-digaonal tau's)
TT = reshape(TT,N-1,N,M); %converting the vector back to matrix

%the step 2 estimated tau's: put back the diagonal terms to the tau matrix
T = ones(N,N,M); 
T(2:end,:,:)=TT;
for i=1:M
    for c=1:N-1
        T(c,c,i)=1; 
        T(c,c+1:N,i)=T(c+1,c+1:N,i);  
    end
end
T(end,end,:)=1; 


%%%%%%%%%%%%%%%%%%%%
%Calculate alpha_h %
%%%%%%%%%%%%%%%%%%%%

%Details of the procedure can be found in the Appendix of the paper

%total exports of the diff. sectors
temp = sum(X,2);
temp = reshape(temp(:),N,M);

%Wage is normalized so that the country with largest export income per worker in diff. sectors don't have to produce homo. goods
%Therefore, no country produce negative homo. good
W1 = max(temp*(1-s)./L)+min(temp*(1-s)./L); %normalize W1 so that the country with largest export per capita just produce minimal amount of homo. goods
WL = L.*W1;

export_homo = (WL-temp*(1-s))./(1-s1); %total export of the homo. goods

%fixed cost
%f = (2/(1+gamma)-1)*export_homo+temp*(2*s-1);

%total imports for the homogenous sector
import_homo = export_homo+sum(sum(X,3),2)-sum(sum(X,3),1)';

%consumption share of the homogeneous good
alpha_h = import_homo./(export_homo+sum(sum(X,3),2));

%equalize the alpha's and alpha_h's across countries (weighted averaged by population size)
alpha_h = repmat(L'*alpha_h/sum(L),M,1);
alpha = repmat(L'*alpha/sum(L),N,1);


%%%%%%%%%%%%%%%%%%
% Benchmark Case %
%%%%%%%%%%%%%%%%%%

[~,X1] = equib(T,A,alpha,alpha_h,M,N,L,theta,s,W1); %X1 denotes the simulated bilateral trade flows data in the benchmark case


%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Counterfactual Analysis %
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change in trade flows across industries when country i is the reference country %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[~,index1] = sortrows(v_a); %finding country's relative position according to skill dispersion
[~,index2] = sortrows(lambda); %finding country's relative position according to lambda's

temp3 = zeros(N,M); %percentage change in exports across industries
temp4 = zeros(N,M); %percentage change in imports across industries
temp = zeros(N,1); %percentage change in aggregate trade flows

for i = 1:18 %the experienet is carried out country by country
    AA = repmat(A(i,:),N,1); %counterfactual: equalizing A's to be i'th country's level
    [~,X2] = equib(T,AA,alpha,alpha_h,M,N,L,theta,s,W1); %X2 denotes the simulated bilateral trade flows data in the counterfactural case
    
    %percentage change in exports across industries
    temp1_e = X1(i,:,:); %extract country i's export data (bench mark case)
    temp1_e(:,i,:) = []; %remove the export to the country itself
    temp1_e = sum(temp1_e,2); %sum over the importing countries and obtain the total exports across industries
    temp1_e = temp1_e(:); %vectorization
    temp2_e = X2(i,:,:); %same as above, but for the counterfactual case
    temp2_e(:,i,:) = [];
    temp2_e = sum(temp2_e,2);
    temp2_e = temp2_e(:);
    temp3(i,:) = (temp2_e-temp1_e)./temp1_e*100; %percentage change in exports across industries for country i

    %percentage change in imports across industries
    temp1_i = X1(:,i,:); %same as above, but for the import case
    temp1_i(i,:,:) = [];
    temp1_i = sum(temp1_i,1);
    temp1_i = temp1_i(:);
    temp2_i = X2(:,i,:);
    temp2_i(i,:,:) = [];
    temp2_i = sum(temp2_i,1);
    temp2_i = temp2_i(:);
    temp4(i,:) = (temp2_i-temp1_i)./temp1_i*100; %percentage change in imports across industries for country i   
    
    temp_X1 = zeros(N-1,N,M);
    temp_X2 = zeros(N-1,N,M);
    for j = 1:M
        temp_X11 = X1(:,:,j);
        temp_X22 = X2(:,:,j);
        temp_X11(logical(eye(N))) = [];
        temp_X22(logical(eye(N))) = [];
        temp_X1(:,:,j) = reshape(temp_X11,N-1,N);
        temp_X2(:,:,j) = reshape(temp_X22,N-1,N);
    end
        
    temp(i) = (sum(sum(sum(temp_X2)))-sum(sum(sum(temp_X1))))/sum(sum(sum(temp_X1)))*100; %percentage change in aggregate trade flows
end


cou = countries(index1); %sort the countries by skill dispersion
temp3 = temp3(index1,index2); %sort the coutries (rows) by skill dispersion; sort the industries (columns) by lambda's
temp4 = temp4(index1,index2); %sort the coutries (rows) by skill dispersion; sort the industries (columns) by lambda's
 

% Figure: change in trade flows across industries: 18 countries
figure(1)
for i =1:N
   title1 = ['Exp by Ind:' ' ' cou{i}];
   title2 = ['Imp by Ind:' ' ' cou{i}];
   
    if i<=9 %countries with low skill dispersion
        subplot(4,9,i)
        %scatter((1:1:63),temp3(i,:),6);lsline;axis([1 63 -20 20]);
        scatter((1:1:63),temp3(i,:),6);axis([1 63 -13 13]);
        title (title1);
        subplot(4,9,9+i)
        %scatter((1:1:63),temp4(i,:),6);lsline;axis([1 63 -20 20]);
        scatter((1:1:63),temp4(i,:),6);axis([1 63 -13 13]);
        title (title2);
    end
    
    if i>9 %countries with high skill dispersion
        j = i-9;
        subplot(4,9,18+j)
        %scatter((1:1:63),temp3(i,:),6);lsline;axis([1 63 -20 20])
        scatter((1:1:63),temp3(i,:),6);axis([1 63 -13 13])
        title (title1);
        subplot(4,9,27+j)
        %scatter((1:1:63),temp4(i,:),6);lsline;axis([1 63 -20 20])
        scatter((1:1:63),temp4(i,:),6);axis([1 63 -13 13])
        title (title2);
    end
    
end

% Figure: Isolate the cases of Germany and US
figure(2)
subplot(2,2,1)
%scatter((1:1:63),temp3(2,:),6);lsline;axis([1 63 -13 13]);
scatter((1:1:63),temp3(2,:),6);axis([1 63 -8 8]);
title1 = ['Exp by Ind:' ' ' cou{2}];
title (title1);
subplot(2,2,3)
%scatter((1:1:63),temp4(2,:),6);lsline;axis([1 63 -13 13]);
scatter((1:1:63),temp4(2,:),6);axis([1 63 -8 8]);
title2 = ['Imp by Ind:' ' ' cou{2}];
title (title2);
subplot(2,2,2)
%scatter((1:1:63),temp3(15,:),6);lsline;axis([1 63 -13 13]);
scatter((1:1:63),temp3(15,:),6);axis([1 63 -8 8]);
title1 = ['Exp by Ind:' ' ' cou{15}];
title (title1);
subplot(2,2,4)
%scatter((1:1:63),temp4(15,:),6);lsline;axis([1 63 -13 13]);
scatter((1:1:63),temp4(15,:),6);axis([1 63 -8 8]);
title2 = ['Imp by Ind:' ' ' cou{15}];
title (title2);

% Total absolute changes 
temp5 = abs(temp3);
temp6 = abs(temp4);
total_export = mean(temp5,2); %taking average across industries
total_import = mean(temp6,2);

total_export_10 = mean(temp3(:,6),2); %10 percentile: export case
total_export_90 = mean(temp3(:,58),2); %90 percentile: export case
total_import_10 = mean(temp4(:,6),2); %10 percentile: import case
total_import_90 = mean(temp4(:,58),2); %90 percentile: import case

if gamma == 0.5
    save('total1','total_export','total_import','total_export_10','total_export_90','total_import_10','total_import_90')
end

if gamma == 0.3
    save('total2','total_export','total_import','total_export_10','total_export_90','total_import_10','total_import_90')
end

if gamma == 0.7
    save('total3','total_export','total_import','total_export_10','total_export_90','total_import_10','total_import_90')
end

%w_export = sum(sum(X,3),2)/sum(sum(sum(X))); %weighting using the real data
%w_import = (sum(sum(X,3),1)/sum(sum(sum(X))))'; %weighting using the real data

w_export = sum(sum(X1,3),2)/sum(sum(sum(X1))); %weighting using the benchmark simulated data
w_import = (sum(sum(X1,3),1)/sum(sum(sum(X1))))'; %weighting using the benchmark simulated data

total_e = sum(total_export.*w_export); %weighted average of absolute changes in trade flows
total_i = sum(total_import.*w_import); %weighted average of absolute changes in trade flows


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%
% print results to Latex %
%%%%%%%%%%%%%%%%%%%%%%%%%%

load('total1') %compensation: gamma=0.5
total_export1 = total_export;
total_import1 = total_import;
total_export_10_1 = total_export_10;
total_export_90_1 = total_export_90;
total_import_10_1 = total_import_10;
total_import_90_1 = total_import_90;

load('total2') %compensation: gamma=0.3
total_export2 = total_export;
total_import2 = total_import;
total_export_10_2 = total_export_10;
total_export_90_2 = total_export_90;
total_import_10_2 = total_import_10;
total_import_90_2 = total_import_90;

load('total3') %compensation: gamma=0.7
total_export3 = total_export;
total_import3 = total_import;
total_export_10_3 = total_export_10;
total_export_90_3 = total_export_90;
total_import_10_3 = total_import_10;
total_import_90_3 = total_import_90;


% results: gamma=0.5 (change in trade flows)
for i = 1:18
    fprintf('%s & %8.2f & %8.2f & %8.2f & & %8.2f & %8.2f & %8.2f \\\\  \n', cou{i},total_export1(i),total_export_10_1(i),total_export_90_1(i),total_import1(i),total_import_10_1(i),total_import_90_1(i))
end

% results: gamma=0.3 (change in trade flows)
for i = 1:18
    fprintf('%s & %8.2f & %8.2f & %8.2f & & %8.2f & %8.2f & %8.2f \\\\  \n', cou{i},total_export2(i),total_export_10_2(i),total_export_90_2(i),total_import2(i),total_import_10_2(i),total_import_90_2(i))
end

% results: gamma=0.7 (change in trade flows)
for i = 1:18
    fprintf('%s & %8.2f & %8.2f & %8.2f & & %8.2f & %8.2f & %8.2f \\\\  \n', cou{i},total_export3(i),total_export_10_3(i),total_export_90_3(i),total_import3(i),total_import_10_3(i),total_import_90_3(i))
end


% report the values of lambda's
load 'industry'
industry(1,:) = [];
industry = strrep(industry,'"','');

fprintf('\\begin{tabular}{cccc}\\hline \n');
fprintf('industry & gamma=0.3 & gamma=0.5 & gamma=0.7 \\\\ \\hline \n');
for i = 1:63
    fprintf('%s & %8.2f & %8.2f & %8.2f\\\\  \n', industry{i},lambda_new(i,1),lambda_new(i,3),lambda_new(i,5))
end
fprintf('\n');
fprintf('\\end{tabular}\n');













