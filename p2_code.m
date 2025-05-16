
% LEITURA DOS DADOS DO EXCEL
dados = readmatrix('entradas.xlsx');  % [Nó, X, Y, E, A, Tipo de apoio]
dados = dados(:, 1:8);  % Garante apenas 8 colunas úteis

%% =======================
% GERAÇÃO DAS PROPRIEDADES DOS ELEMENTOS

tabela = propriedades_elementos_conectividade(dados);

%% =======================
% GERAÇÃO DAS MATRIZES DE RIGIDEZ LOCAIS
matrizes_rigidez = matriz_rigized(tabela);
matriz_rigized_global = calculo_matrizes_rigidez_global(matrizes_rigidez,tabela);
vetor_forcas_global = calculo_vetor_forcas_global(dados);
[tabela_K_reduzida, tabela_PG_reduzida] =eliminar_reacoes(matriz_rigized_global, vetor_forcas_global)
tabela_deslocamentos_global = calculo_tabela_deslocamentos(tabela_K_reduzida, tabela_PG_reduzida, vetor_forcas_global)
%% =======================
% EXIBIÇÃO DE TABELAS NO CONSOLE
disp(tabela)
disp(matrizes_rigidez)
disp(matriz_rigized_global)
disp(vetor_forcas_global)
disp(tabela_K_reduzida)
disp(tabela_PG_reduzida)
disp(tabela_deslocamentos_global);

%% =======================
% PLOTAGEM DA MALHA COM APOIOS E COMPRIMENTOS
figure;
hold on;
for i = 1:height(tabela)
    incidencia_str = tabela.('Incidência')(i);     % Ex: "3-1"
    tokens = split(incidencia_str, '-');
    ni = str2double(tokens{1});
    nj = str2double(tokens{2});

    xi = dados(ni,2); yi = dados(ni,3);
    xj = dados(nj,2); yj = dados(nj,3);

    adicionar_apoio(dados(ni,2), dados(ni,3), dados(ni,6));

    padding = 0.01;
    xmin = min(dados(:,2)) - padding;
    xmax = max(dados(:,2)) + padding;
    ymin = min(dados(:,3)) - padding;
    ymax = max(dados(:,3)) + padding;
    xlim([xmin xmax]);
    ylim([ymin ymax]);

    h_linha = plot([xi xj], [yi yj], 'b-o', ...
        'DisplayName', sprintf('Elemento %d: L = %.2f m', i, tabela.("L (m)")(i)));

    % Exibe valor de L no centro da barra
    xc = (xi + xj)/2;
    yc = (yi + yj)/2;
    text(xc+0.005, yc-0.02, sprintf('L=%.2f', tabela.("L (m)")(i)), ...
        'FontSize', 9, 'Color', 'blue', 'FontWeight', 'bold');
end

% Números dos nós
for i = 1:size(dados,1)
    text(dados(i,2) + 0.005, dados(i,3) - 0.01, sprintf(' %d', i), ...
        'FontSize', 10, 'Color', 'black', 'FontWeight', 'bold');
end

% Elemento invisível para associar à legenda do número do nó
h_legenda_nos = plot(nan, nan, 'k.', 'DisplayName', 'Número do nó');
legend(h_legenda_nos, 'Location', 'bestoutside');

title('Treliças');
axis equal;
xlabel('X'); ylabel('Y');
set(gca, 'XColor', 'none', 'YColor', 'none');


%% =======================
% FUNÇÃO: GERAÇÃO DE CONECTIVIDADE TRIANGULAR
function conectividade = gerar_conectividade_triangulos(dados)
    n_nos = size(dados, 1);
    conectividade = [];
    contador = 1;

    for i = 1:n_nos - 1
        no_i = i;
        no_j = i + 1;
        conectividade = [conectividade; no_i, no_j];
        contador = contador + 1;

        if mod(contador, 3) == 0 
            conectividade = [conectividade; no_j, no_j - 2];  % Fecha triângulo: 3–1
        end
    end
end

%% =======================
% FUNÇÃO: PROPRIEDADES DOS ELEMENTOS

function tabela = propriedades_elementos_conectividade(dados)
    conectividade = gerar_conectividade_triangulos(dados);
    n_elem = size(conectividade, 1);

    A_list = zeros(n_elem, 1);
    E_list = zeros(n_elem, 1);
    c_list = zeros(n_elem, 1);
    s_list = zeros(n_elem, 1);
    L_list = zeros(n_elem, 1);
    dofs   = zeros(n_elem, 4);
    incidencias = strings(n_elem, 1);

    for i = 1:n_elem
        no_i = conectividade(i, 1);
        no_j = conectividade(i, 2);

        xi = dados(no_i, 2);  yi = dados(no_i, 3);
        xj = dados(no_j, 2);  yj = dados(no_j, 3);
        E  = dados(no_i, 4);
        A  = dados(no_i, 5);

        L = sqrt((xj - xi)^2 + (yj - yi)^2);
        c = (xj - xi) / L;
        s = (yj - yi) / L;

        L_list(i) = L;
        c_list(i) = c;
        s_list(i) = s;
        E_list(i) = E;
        A_list(i) = A;
        dofs(i, :) = [2*no_i - 1, 2*no_i, 2*no_j - 1, 2*no_j];
        incidencias(i) = sprintf('%d-%d', no_i, no_j);
    end

    tabela = table((1:n_elem)', incidencias, ...
        A_list, E_list, c_list, s_list, L_list, dofs, ...
        'VariableNames', {'Elemento','Incidência', ...
        'Area (m^2)', 'E (Pa)', 'c', 's', 'L (m)', ...
         'Graus_de_Liberdade'});
end

%% =======================
% FUNÇÃO: MATRIZES DE RIGIDEZ LOCAIS
function lista_matrizes_rigidez = matriz_rigized(tabela)
    Ke_cel = cell(height(tabela), 1);
    nomes = strings(height(tabela), 1);

    for i = 1:height(tabela)
        E = tabela.("E (Pa)")(i);
        A = tabela.("Area (m^2)")(i);
        l = tabela.("L (m)")(i);
        c = tabela.("c")(i);
        s = tabela.("s")(i);

        M = [c^2,  c*s, -c^2, -c*s;
             c*s,  s^2, -c*s, -s^2;
            -c^2, -c*s,  c^2,  c*s;
            -c*s, -s^2,  c*s,  s^2];

        Ke = (E * A / l) * M;
        Ke_cel{i} = Ke;
        nomes(i) = "Ke" + string(i);
    end

    lista_matrizes_rigidez = table(nomes, Ke_cel, ...
        'VariableNames', {'Nome', 'Matriz_Ke'});
end


%% =======================
% FUNÇÃO: MATRIZ DE RIGIDEZ GLOBAL
function tabela_matrizes_rigidez_global = calculo_matrizes_rigidez_global(matrizes_rigidez, tabela)
    n = height(tabela);

    % Determina o número total de graus de liberdade
    total_dofs = max(tabela.Graus_de_Liberdade(:));

    % Inicializa a matriz de rigidez global
    K_global = zeros(total_dofs);

    % Percorre cada elemento
    for i = 1:n
        Ke = matrizes_rigidez.Matriz_Ke{i};  % matriz local 4x4
        dofs = tabela.Graus_de_Liberdade(i, :);  % vetor de DOFs globais
        
        % com isso, para cada elemento da tabela de graus de liberdade é
        % associado a uma possição da tabela local.
        for r = 1:4
            for c = 1:4
                i_global = dofs(r);
                j_global = dofs(c);
                K_global(i_global, j_global) = K_global(i_global, j_global) + Ke(r, c);
            end
        end
    end
    tabela_matrizes_rigidez_global = table(K_global, ...
    'VariableNames', {'Matriz de Rigidez Global'});
end

%% =======================
% FUNÇÃO:Vetor Global de Forças
function tabela_vetor_forcas_global = calculo_vetor_forcas_global(dados)
    n_nos = size(dados, 1);
    vetor_forcas_global = cell(2 * n_nos, 1);

    for i = 1:n_nos
        Fx = dados(i, 7);
        Fy = dados(i, 8);
        tipo_apoio = dados(i, 6);

        dof_x = 2*i - 1;
        dof_y = 2*i;

        % DOF X
        if tipo_apoio == 1 || tipo_apoio == 2  % Pino ou Rolete
            vetor_forcas_global{dof_x} = "R" + string(i) + "x";
        else
            vetor_forcas_global{dof_x} = Fx;
        end

        % DOF Y
        if tipo_apoio == 1  % Pino, Rolete
            vetor_forcas_global{dof_y} = "R" + string(i) + "y";
        else
            vetor_forcas_global{dof_y} = Fy;
        end
    end
    tabela_vetor_forcas_global= table(vetor_forcas_global, ...
    'VariableNames', {'PG'});
end
%% =======================
% FUNÇÃO: REMOÇÃO DE REAÇÕES
function [tabela_K_reduzida, tabela_PG_reduzida] = eliminar_reacoes(matriz_rigized_global, vetor_forcas_global)
    % Se vetor_forcas_global for uma tabela, extrai a coluna
    if istable(vetor_forcas_global)
        vetor_forcas_global = vetor_forcas_global{:,:};
    end

    % Se matriz_rigized_global for tabela, extrai a matriz numérica
    if istable(matriz_rigized_global)
        matriz_rigized_global = matriz_rigized_global.("Matriz de Rigidez Global");
    end

    n = numel(vetor_forcas_global);
    indices_livres = false(n, 1);

    for i = 1:n
        if isnumeric(vetor_forcas_global{i}) && ~isnan(vetor_forcas_global{i})
            indices_livres(i) = true;
        end
    end

    K_reduzida = matriz_rigized_global(indices_livres, indices_livres);

    F_reduzido = zeros(sum(indices_livres), 1);
    j = 1;
    for i = 1:n
        if indices_livres(i)
            F_reduzido(j) = vetor_forcas_global{i};
            j = j + 1;
        end
    end
    tabela_K_reduzida= table(K_reduzida, ...
    'VariableNames', {'Matriz de Rigidez Global reduzida'});
    tabela_PG_reduzida= table(F_reduzido, ...
    'VariableNames', {'Matriz de PG reduzida'});
end
%% =======================
% FUNÇÃO: Obtendo desolcamento
function tabela_deslocamentos_global = calculo_tabela_deslocamentos(tabela_K_reduzida, tabela_PG_reduzida, vetor_forcas_global)
    % Resolve o sistema linear simbolicamente
    n_reduzidas = height(tabela_PG_reduzida);
    U = sym('u', [n_reduzidas, 1]);

    K = tabela_K_reduzida.("Matriz de Rigidez Global reduzida");
    F = tabela_PG_reduzida.("Matriz de PG reduzida");
    U_sol = solve(K * U == F, U);

    % Cria vetor global de deslocamentos
    vetor_forcas_global = vetor_forcas_global{:,:};  % extrai se for tabela
    n_total = numel(vetor_forcas_global);
    U_global = sym(zeros(n_total, 1));

    idx = 1;
    for i = 1:n_total
        if isnumeric(vetor_forcas_global{i})
            U_global(i) = U_sol.(sprintf('u%d', idx));
            idx = idx + 1;
        end
    end

    % Arredonda os resultados para 4 dígitos e converte para double
    valores_aproximados = double(vpa(U_global, 4));

    % Gera nomes das variáveis u1, u2, ..., un
    nomes = arrayfun(@(i) sprintf('u%d', i), 1:n_total, 'UniformOutput', false);
    tabela_deslocamentos_global = table(valores_aproximados, ...
        'RowNames', nomes, ...
        'VariableNames', {'Deslocamento'});
end
%% =======================
% FUNÇÃO: DESENHO DOS APOIOS
function adicionar_apoio(x, y, tipo)
    hold on;
    switch tipo
        case 0
            % sem apoio
        case 1  % Pino
            plot(x, y, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'green');
            text(x - 0.05, y, 'Pino', 'FontSize', 9);
        case 2  % Rolete
            plot(x, y, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'green');
            text(x - 0.06, y, 'Rolete', 'FontSize', 9);
        otherwise
            warning('Tipo de apoio inválido. Use 1 = Pino, 2 = Rolete, 3 = Engaste.');
    end
end

