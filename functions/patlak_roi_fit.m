function [Ki, V0, R2, X, Y, yfit] = patlak_roi_fit(Cp, Ct, t_mid, fitWindow)

Cp = Cp(:);
Ct = Ct(:);
t_mid = t_mid(:);

Cp(Cp <= 0) = eps;

AUCp = cumtrapz(t_mid, Cp);

X = AUCp ./ Cp;
Y = Ct ./ Cp;

p = polyfit(X(fitWindow), Y(fitWindow), 1);

Ki = p(1);
V0 = p(2);

yfit = polyval(p, X(fitWindow));

R2 = 1 - sum((Y(fitWindow)-yfit).^2) / ...
         sum((Y(fitWindow)-mean(Y(fitWindow))).^2);

end