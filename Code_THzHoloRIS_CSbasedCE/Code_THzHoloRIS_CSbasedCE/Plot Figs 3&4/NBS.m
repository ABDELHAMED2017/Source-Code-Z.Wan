function g = NBS(x,y,d,N,lambda,k_opt,l_opt)
    % x,y�ֱ�Ϊ��λ�������ǣ�����ά�ȱ�����ͬ
    % ��֤�����������Ϊ������
    gx = diric(d*2*pi/lambda*(k_opt-x),N);
    gy = diric(d*2*pi/lambda*(l_opt-y),N);
    
    g = gx.*gy;
end