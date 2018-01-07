function [rnd] = lfsr(s, t, n, m, len)
bv = de2bi(s, n, 'left-msb');
tap = zeros(1, n);
for i=1:length(t)
   tap(t(i)) = 1;
end

rnd = zeros(len, 1);
for j=1:len
    
    tmp = bv(n);
    for i=(n - 1):-1:1
        if tap(i) == 1
            bv(i + 1) = bitxor(bv(i), tmp);
        else
            bv(i + 1) = bv(i);
        end
    end
    bv(1) = tmp;
    rnd(j) = bi2de(bv(end:-1:end-m+1));
end

% rnd = bv(end);
%rnd = bi2de(bv, 'left-msb');