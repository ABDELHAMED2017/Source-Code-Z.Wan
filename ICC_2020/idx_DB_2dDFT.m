function idx = idx_DB_2dDFT(Nx, Ny)
% �ҵ�2dDFT�����ж�Ӧsin�����Ǵ���0��idx
% Nx NyΪ2dDFT����ά�ȣ����������¶�Ӧ�ڶ���ά���еĽǶȴ���0
% Ϊ���㣬��֤����Ϊż��

    idx = [];
    for i = 1:Nx
        for j = 1:Ny/2+1
            idx = union(idx,sub2ind([Nx,Ny],j,i));
        end
    end
end
% [1:Ny/2+2,Ny]
% Ny/2+3:Ny-1