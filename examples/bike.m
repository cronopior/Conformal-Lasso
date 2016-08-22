function [coverage,l] = bike(yind)
%% Import data from spreadsheet
% Script for importing data from the following spreadsheet:
%
%    Workbook: E:\Github\Conformal-Lasso\examples\3quarters.xlsx
%    Worksheet: clean
%
% To extend the code for use with different selected data or a different
% spreadsheet, generate a function instead of a script.

% Auto-generated by MATLAB on 2016/07/25 02:12:52

%% Import the data
[~, ~, raw] = xlsread('3quarters.xlsx','clean');
raw(cellfun(@(x) ~isempty(x) && isnumeric(x) && isnan(x),raw)) = {''};

%% Replace non-numeric cells with NaN
R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),raw); % Find non-numeric cells
raw(R) = {NaN}; % Replace non-numeric cells

%% Create output variable
quartersS1 = reshape([raw{:}],size(raw));

%% Clear temporary variables
clearvars raw R;

data = quartersS1;
[m,p]=size(data);
dayone=[];
for i=1:p
    t=find(data(:,i));
    dayone=[dayone t(1)];
end
[~,id]=max(diff(dayone));
D=data(dayone(id):(dayone(id+1)-1),1:id);

[newm,newp]=size(D);
normD = D - min(D(:));
md=max(normD(:));
normD = normD ./ md;

Ytot = normD(:,yind);
meanYtot = mean(Ytot);
maxYtot = max(abs(Ytot));

Ytot = Ytot-meanYtot ;
Ytot = Ytot/maxYtot;
Xtot = normD(:,setxor(1:newp,yind));
Xtot = (Xtot - 0.5)*2;
if newm<20
    fprintf('Too few.\n');
    return;
end

nsample = 92;
fitind = randsample(1:newm,nsample);
Xtrain = Xtot(fitind,:);
Ytrain = Ytot(fitind);
Xtest = Xtot(setxor(1:newm,fitind),:);
Ytest = Ytot(setxor(1:newm,fitind),:);
n = length(Ytest);

folder = fullfile(pwd, '\Outputs');
filename = sprintf('BikeWithRespone_%d.txt',yind);
fileID = fopen(fullfile(folder, filename),'w');
fileID = fopen('bike_ALL','w');

incounter = 0;
fprintf(fileID,'Taking Station number %d as response.\n',yind);
L = [];
U = [];
for i=1:n
    xnew = Xtest(i,:);
    X_withnew = [Xtrain;xnew];
    y = Ytest(i);
    ytrial = -1:0.01:1;  
    
    try
        [yconf,modelsize,sc] = conformalLOO(Xtrain,Ytrain,xnew,.1,ytrial,0.1);
    catch ME
        yconf = ytrial;
        modelsize = 0; sc=0;
        fprintf('GLMNET ERROR\n');
    end
    fprintf(fileID,'Prediction interval is [%.2f,%.2f] with model size %.2f while real data is %.0f\n',...
        min(yconf)*md*maxYtot+meanYtot,max(yconf)*md*maxYtot+meanYtot,modelsize,y*md*maxYtot+meanYtot);
    if (min(yconf)<=y)&&(y<=max(yconf))
        incounter=incounter+1;
        fprintf(fileID,'Real data is IN\n');
    else
        fprintf(fileID,'Real data is OUT\n');
    end
    L = [L min(yconf)];
    U = [U max(yconf)];
end

plot(1:(newm-nsample),(Ytest*maxYtot+meanYtot)*md,'bo');
hold on;
plot([find(U'-Ytest<0)' find(L'-Ytest>0)'],...
    md*(maxYtot*Ytest([find(U'-Ytest<0)' find(L'-Ytest>0)'])+meanYtot),'ro');
for i=1:(newm-nsample)
    line([i i], [(L(i)*maxYtot+meanYtot)*md (U(i)*maxYtot+meanYtot)*md]);
end
title(sprintf('Conformal Prediction intervals for Station %d',yind));
hold off;
fprintf(fileID,'The coverage is %.3f\n',incounter/(newm-nsample));
fclose(fileID);
coverage = incounter/(newm-nsample);
l= (mean(U-L)*maxYtot++meanYtot)*md;