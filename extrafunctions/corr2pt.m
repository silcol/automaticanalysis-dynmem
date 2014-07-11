% Converts a correlation coefficient C ("R value"), derived from correlating
% 2 sets of data of length N, into a p and t value
function [p t] = corr2pt(C, N)

t = C ./ sqrt((1-C.^2) ./ (N-2));
p = 1 - tcdf(abs(t), N-2);