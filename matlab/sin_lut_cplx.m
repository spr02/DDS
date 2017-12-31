function [val_sin, val_cos] = sin_lut_cplx(input_val, input_width, output_width)
    % get first MSB
    MSB_0 = floor(input_val / pow2(input_width - 1));
    
    % get second MSB
    MSB_1 = floor(input_val / pow2(input_width - 2)) - 2 * MSB_0;
    
    % only the lower (input_width - 2) bits as we only address a quater wave
    LSB = input_val - (floor(input_val / pow2(input_width - 2)) * pow2(input_width - 2));
%     LSB_grad = mod(LSB + 1, pow2(input_width));


    % invert ADDRESS if MSB_1 == 1 (first symmety) and plus 1???
    % so actually take two's complement!
    addr = pow2(input_width - 2) * MSB_1 + (1-2*MSB_1) .* LSB;
    addr = mod(addr, pow2(input_width - 2));
%     addr(addr > (pow2(input_width - 2) - 1)) = pow2(input_width - 2) - 1;
    
%     addr_grad = pow2(input_width - 2) * MSB_1 + (1-2*MSB_1) .* LSB_grad;
%     addr_grad = mod(addr_grad, pow2(input_width - 2));
%     addr_grad(addr_grad > (pow2(input_width - 2) - 1)) = pow2(input_width - 2) - 1;
    

    val_sin = sin(2 * pi * (addr) / pow2(input_width));
    val_sin = round( (pow2(output_width-1) - 1) * val_sin );
    val_sin((MSB_1 == 1) & (LSB == 0)) = pow2(output_width - 1) - 1;
    
    val_cos = cos(2 * pi * (addr) / pow2(input_width));
    val_cos = round( (pow2(output_width-1) - 1) * val_cos );
    val_cos((MSB_1 == 1) & (LSB == 0)) = 0;
    
%     grad = sin(2 * pi * (addr_grad) / pow2(input_width));
%     grad = round( (pow2(output_width-1) - 1) * grad );
%     grad = grad - val;
%     grad((MSB_1 == 0) & (LSB == (pow2(input_width - 2) - 1))) = 10;
    
    
%     i = 0:2^(input_width-2)-1;
%     LUT = sin(i/2^input_width * 2 * pi);
%     LUT = round((2^(output_width-1)-1)*LUT);
%     val = LUT(addr + 1);
%     
%     LUT_grad = [LUT LUT(end)] - [0 LUT];
%     LUT_grad = LUT_grad(2:end);
%     LUT_grad(end) = 0;
    
%     grad = (1-2*inv_gradient) .* grad;
%     grad(LSB == (pow2(input_width - 2) - 1)) = 0;
    
    % quantize value to output bit width
    
    
    
    % multiply by -1 if MSB_0 == 1 (second symmetry)
    inv_cos = (MSB_0 + MSB_1) == 1;
    val_sin = (1-2*MSB_0) .* val_sin;
    val_cos = (1-2*inv_cos) .* val_cos;
end

