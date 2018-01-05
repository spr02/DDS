function [out] = bin_usgn_to_sgn(in, width)
    max_usgn_val = pow2(width) - 1;         % max unsigned value
    max_sgn_val  = pow2(width - 1) - 1;     % max positive signed value
    min_sgn_val  = -pow2(width - 1);
    out = in - (max_usgn_val + 1) * (in > max_sgn_val);
end

