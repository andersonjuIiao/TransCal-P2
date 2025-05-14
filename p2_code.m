% Lê os dados do Excel (sem cabeçalhos)
dados = readmatrix('entradas.xlsx');
dados = dados(:, 1:3);  % Mantém apenas as colunas: Nó, X, Y

% Chama a função
tabela = propriedades_elementos(dados);

% Exibe a tabela
disp(tabela)

% Função sem conectividade explícita
function tabela = propriedades_elementos(dados)
    n_nos = size(dados, 1);
    n_elem = n_nos;

    E = 210e9;   % Pa // DEVE SER PASSADO MAS É PROVISÓRIO
    A = 2e-4;    % m² // DEVE SER PASSADO MAS É PROVISÓRIO
    nos_list = zeros(n_elem, 1);
    x_list = zeros(n_elem, 1);
    y_list = zeros(n_elem, 1);

    c_list = zeros(n_elem, 1);
    s_list = zeros(n_elem, 1);
    L_list = zeros(n_elem, 1);
    
    dofs = zeros(n_elem, 4);

    for i = 1:n_elem

        nos_list(i) =  dados(i, 1);
        x_list(i) = dados(i, 2);
        y_list(i) = dados(i, 3);
        
        no_i = i;
        no_j = mod(i, n_nos) + 1;  % Nó seguinte (circular)
        
        xi = dados(no_i, 2);  yi = dados(no_i, 3);
        xj = dados(no_j, 2);  yj = dados(no_j, 3);

        L = sqrt((xj - xi)^2 + (yj - yi)^2);
        c = (xj - xi) / L;
        s = (yj - yi) / L;

        L_list(i) = L;
        c_list(i) = c;
        s_list(i) = s;

        dofs(i, :) = [2*no_i - 1, 2*no_i, 2*no_j - 1, 2*no_j];

    end

    tabela = table(nos_list, ...
                   x_list, ...
                   y_list, ...
                   (1:n_elem)', ...
                   repmat(A, n_elem, 1), ...
                   repmat(E, n_elem, 1), ...
                   c_list, ...
                   s_list, ...
                   L_list, ...
                   dofs, ...
                   'VariableNames', {'Número do nó','x (m)','y (m)' ,'Elemento', 'Area (m^2)', 'E (Pa)', 'c', 's', 'L (m)', 'Graus_de_Liberdade'});
end
