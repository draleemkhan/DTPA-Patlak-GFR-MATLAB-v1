function [KiMap, R2Map] = patlak_parametric_maps(img, Cp, t_mid, fitWindow, kidneyMask)

Cp = Cp(:);
t_mid = t_mid(:);
Cp(Cp <= 0) = eps;

[nx, ny, nf] = size(img);

AUCp = cumtrapz(t_mid, Cp);
X = AUCp ./ Cp;

KiMap = nan(nx,ny);
R2Map = nan(nx,ny);

[xpix, ypix] = find(kidneyMask);

for k = 1:length(xpix)

    x = xpix(k);
    y = ypix(k);

    Ct = squeeze(img(x,y,:));
    Ct = Ct(:);

    if length(Ct) ~= length(Cp)
        n = min(length(Ct), length(Cp));
        Ct = Ct(1:n);
        Cp2 = Cp(1:n);
        X2 = X(1:n);
        fw = fitWindow(1:n);
    else
        Cp2 = Cp;
        X2 = X;
        fw = fitWindow;
    end

    Y = Ct ./ Cp2;

    if all(isfinite(Y(fw))) && max(Ct) > 0

        p = polyfit(X2(fw), Y(fw), 1);

        yfit = polyval(p, X2(fw));

        KiMap(x,y) = p(1);

        denom = sum((Y(fw)-mean(Y(fw))).^2);

        if denom > 0
            R2Map(x,y) = 1 - sum((Y(fw)-yfit).^2) / denom;
        end
    end
end

end