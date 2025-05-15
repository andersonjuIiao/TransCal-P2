% Lê os dados do Excel (sem cabeçalhos)
dados = readmatrix('entradas.xlsx');
dados = dados(:, 1:5);  % Mantém apenas as colunas: Nó, X, Y,E,A


% Função sem conectividade explícita
function tabela = propriedades_elementos(dados)
    n_nos = size(dados, 1);
    n_elem = n_nos;


    E_list = zeros(n_elem, 1);
    A_list = zeros(n_elem, 1);
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
        E_list(i)=  dados(i, 4);
        A_list(i)=  dados(i, 5);

        
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
                   A_list, ...
                   E_list, ...
                   c_list, ...
                   s_list, ...
                   L_list, ...
                   dofs, ...
                   'VariableNames', {'Número do nó','x (m)','y (m)' ,'Elemento', 'Area (m^2)', 'E (Pa)', 'c', 's', 'L (m)', 'Graus_de_Liberdade'});
end


function lista_matrizes_rigidez = matriz_rigized(tabela)
    Ke_cel = cell(height(tabela), 1);
    nomes = strings(height(tabela), 1);  % vetor de nomes "Ke1", "Ke2", ...

    for  i = 1:height(tabela)
            E = tabela.('E (Pa)')(i);
            A = tabela.('Area (m^2)')(i);
            l = tabela.('L (m)')(i);
            c = tabela.('c')(i);
            s = tabela.('s')(i);
            M = [c^2,c*s,-c^2,-c*s;
                c*s, s^2, -c*s, -s^2;
                -c^2,-c*s, c^2 , c*s;
                -c*s, -s^2, c*s, s^2];
            
            Ke = ((E*A)/l) * M;
            Ke_cel{i} = Ke;
            nomes(i) = "Ke" + string(i);  % Cria nome: "Ke1", "Ke2", ...
    end
    lista_matrizes_rigidez = table(nomes, Ke_cel, ...
        'VariableNames', {'Nome', 'Matriz_Ke'});


end



% Chama a função
tabela = propriedades_elementos(dados);
matrizes_rigidez = matriz_rigized(tabela);
% Exibe a tabela
disp(tabela)
disp(matrizes_rigidez)
% Exibir nome da 2ª matriz
% disp(matrizes_rigidez.Nome(2))  % --> "Ke2"

% Exibir a matriz correspondente
% disp(matrizes_rigidez.Matriz_Ke{2})