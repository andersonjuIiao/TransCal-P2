% =======================
% LEITURA DOS DADOS DO EXCEL (CORRIGIDO)

% Leitura da aba "Nós e Coordenadas"
dados_nos_tbl = readtable('entradas.xlsx', 'Sheet', 'Nós e Coordenadas');
dados_nos = [ ...
    str2double(string(dados_nos_tbl{:, "Nos"})), ...
    dados_nos_tbl{:, "X"}, ...
    dados_nos_tbl{:, "Y"} ...
];
dados_apoio = dados_nos_tbl{:, "TipoApoio"};

% Leitura da aba "Tabela Elementos"
elementos_tbl = readtable('entradas.xlsx', 'Sheet', 'Tabela Elementos');
conectividade = [elementos_tbl.Incidencia1, elementos_tbl.Incidencia2];
E_list = elementos_tbl.Elasticidade;
A_list = elementos_tbl.Area;

n_nos = size(dados_nos, 1);
dados = zeros(n_nos, 8);  % [ID, X, Y, Tipo Apoio, Fx, Fy, ..., ...]
dados(:,1:3) = dados_nos;
dados(:,4) = dados_apoio;
dados(:,5) = dados_nos_tbl.Fx;  % forças diretamente da aba "Nós e Coordenadas"
dados(:,6) = dados_nos_tbl.Fy;

%% =======================
% GERAÇÃO DAS PROPRIEDADES DOS ELEMENTOS
elementos_tbl = readtable('entradas.xlsx', 'Sheet', 'Tabela Elementos');
conect = gerar_conectividade_do_excel(elementos_tbl);
tabela = propriedades_elementos_conectividade(dados, elementos_tbl);


%% =======================
% GERAÇÃO DAS MATRIZES DE RIGIDEZ LOCAIS
matrizes_rigidez = matriz_rigized(tabela);
matriz_rigized_global = calculo_matrizes_rigidez_global(matrizes_rigidez,tabela);
vetor_forcas_global = calculo_vetor_forcas_global(dados, tabela);

[tabela_K_reduzida, tabela_PG_reduzida] =eliminar_reacoes(matriz_rigized_global, vetor_forcas_global);
tabela_deslocamentos_global = calculo_tabela_deslocamentos(tabela_K_reduzida, tabela_PG_reduzida, vetor_forcas_global);
tabela_deformacoes_tensoes = calcular_deformacoes_tensoes(tabela, tabela_deslocamentos_global);
%% =======================
% EXIBIÇÃO DE TABELAS NO CONSOLE
disp(tabela)
disp(matrizes_rigidez)
disp(matriz_rigized_global)
disp(vetor_forcas_global)
disp(tabela_K_reduzida)
disp(tabela_PG_reduzida)
disp(tabela_deslocamentos_global)
disp(tabela_deformacoes_tensoes);



%% =======================
% FUNÇÃO: GERAÇÃO DE CONECTIVIDADE TRIANGULAR
function conectividade = gerar_conectividade_do_excel(elementos_tbl)
    conectividade = [elementos_tbl.Incidencia1, elementos_tbl.Incidencia2];
end
%% =======================
% FUNÇÃO: PROPRIEDADES DOS ELEMENTOS
function tabela = propriedades_elementos_conectividade(dados,elementos_tbl)
    conectividade = gerar_conectividade_do_excel(elementos_tbl);
    n_elem = size(conectividade, 1);

    ids = dados(:, 1);  % Coluna "Nos"

    A_list = zeros(n_elem, 1);
    E_list = zeros(n_elem, 1);
    c_list = zeros(n_elem, 1);
    s_list = zeros(n_elem, 1);
    L_list = zeros(n_elem, 1);
    dofs   = zeros(n_elem, 4);
    incidencias = strings(n_elem, 1);

    for i = 1:n_elem
        id_i = conectividade(i, 1);
        id_j = conectividade(i, 2);

        idx_i = find(ids == id_i, 1);
        idx_j = find(ids == id_j, 1);

        if isempty(idx_i) || isempty(idx_j)
            error("ID de nó %d ou %d não encontrado na planilha.", id_i, id_j);
        end

        xi = dados(idx_i, 2);  yi = dados(idx_i, 3);
        xj = dados(idx_j, 2);  yj = dados(idx_j, 3);
        E  = elementos_tbl.Elasticidade(i);
        A  = elementos_tbl.Area(i);

        L = sqrt((xj - xi)^2 + (yj - yi)^2);
        c = (xj - xi) / L;
        s = (yj - yi) / L;

        L_list(i) = L;
        c_list(i) = c;
        s_list(i) = s;
        E_list(i) = E;
        A_list(i) = A;

        dofs(i, :) = [2*idx_i - 1, 2*idx_i, 2*idx_j - 1, 2*idx_j];
        incidencias(i) = sprintf('%d-%d', id_i, id_j);
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
function tabela_vetor_forcas_global = calculo_vetor_forcas_global(dados, tabela)
    % DOFs realmente utilizados na estrutura
    total_dofs = max(tabela.Graus_de_Liberdade(:));
    vetor_forcas_global = cell(total_dofs, 1);

    ids = dados(:, 1);  % IDs reais dos nós

    for i = 1:length(ids)
        id = ids(i);  % nó real (ex: 1, 2, 3...)

        dof_x = 2*id - 1;
        dof_y = 2*id;

        Fx = dados(i, 5);
        Fy = dados(i, 6);
        tipo_apoio = dados(i, 4);

        if dof_x <= total_dofs
            if tipo_apoio == 1 || tipo_apoio == 2
                vetor_forcas_global{dof_x} = "R" + string(id) + "x";
            else
                vetor_forcas_global{dof_x} = Fx;
            end
        end

        if dof_y <= total_dofs
            if tipo_apoio == 1
                vetor_forcas_global{dof_y} = "R" + string(id) + "y";
            else
                vetor_forcas_global{dof_y} = Fy;
            end
        end
    end

    tabela_vetor_forcas_global = table(vetor_forcas_global, ...
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

    % Tenta resolver
    U_sol = solve(K * U == F, U, 'ReturnConditions', false);

    % Constrói vetor global
    vetor_forcas_global = vetor_forcas_global{:,:};
    n_total = numel(vetor_forcas_global);
    U_global = sym(zeros(n_total, 1));
    idx = 1;

    % Cria vetor simbólico indexado
    campos = fieldnames(U_sol);
    for i = 1:n_total
        if isnumeric(vetor_forcas_global{i})
            nome = sprintf('u%d', idx);
        if ismember(nome, campos)
            valor = U_sol.(nome);
            if isempty(valor)
                U_global(i) = sym(0);
            elseif isscalar(valor)
                U_global(i) = valor;
            else
                U_global(i) = valor(1);
            end
        else
            U_global(i) = sym(0);  % fallback seguro
        end
            idx = idx + 1;
        end
    end

    valores_aproximados = double(vpa(U_global, 4));
    nomes = arrayfun(@(i) sprintf('u%d', i), 1:n_total, 'UniformOutput', false);
    tabela_deslocamentos_global = table(valores_aproximados, ...
        'RowNames', nomes, ...
        'VariableNames', {'Deslocamento'});
end

%% =======================
% FUNÇÃO: Determinar a deformação e a tensão em cada elemento.
function tabela_deformacoes_tensoes = calcular_deformacoes_tensoes(tabela, deslocamentos)
    % deslocamentos deve ser um vetor (simples ou tabela com uma coluna)

    if istable(deslocamentos)
        deslocamentos = deslocamentos.Deslocamento;
    end

    n_elem = height(tabela);
    deformacoes = zeros(n_elem, 1);
    tensao = zeros(n_elem, 1);
    for e = 1:n_elem
        dofs = tabela.Graus_de_Liberdade(e, :);
        u = deslocamentos(dofs);

        c = tabela.c(e);
        s = tabela.s(e);
        L = tabela.("L (m)")(e);
        E =  tabela.("E (Pa)")(e);

        % Matriz de projeção: diferença de deslocamento ao longo da barra
        B = [-c -s c s];  % projeta deslocamento global ao longo do eixo da barra
            

        
        % Deformação axial

        deformacoes(e) = (1 / L) * (B * u);

        %Tensão 
        tensao(e) = E *deformacoes(e);

    end

    % Retorna em forma de tabela
    tabela_deformacoes_tensoes = table((1:n_elem)', deformacoes,tensao, ...
        'VariableNames', {'Elemento', 'Deformacao','Tensão (Pa)'});
end

function tabela_reacoes = calcular_reacoes_apoio(K_tab, PG_tab, U_tab)
    % Extrai K_global
    if istable(K_tab)
        K_global = K_tab.("Matriz de Rigidez Global");
    else
        K_global = K_tab;
    end

    % Extrai vetor F_global original (células com número ou string)
    if istable(PG_tab)
        PG = PG_tab.PG;
    else
        PG = PG_tab;
    end
    n = numel(PG);

    % Constroi F_ext numérico (loads) e identifica os DOFs livres
    F_ext = zeros(n,1);
    isLivre = false(n,1);
    for i = 1:n
        if isnumeric(PG{i})
            F_ext(i) = PG{i};
            isLivre(i) = true;
        else
            F_ext(i) = 0;
            isLivre(i) = false;
        end
    end

    % Extrai U_global completo (inclui zeros em DOFs restringidos)
    U_global = U_tab.Deslocamento;

    % Calcula vetor completo de forças internas
    R_full = K_global * U_global - F_ext;

    % Seleciona só as reações (DOFs restringidos)
    idxRes = ~isLivre;
    nomes  = cell(sum(idxRes),1);
    valores = R_full(idxRes);
    k = 1;
    for i = 1:n
        if idxRes(i)
            nomes{k} = PG{i};   % ex: "R1x", "R2y", ...
            k = k + 1;
        end
    end

    % Monta tabela de saída
    tabela_reacoes = table(nomes, valores, ...
        'VariableNames', {'Reacao','Valor'});
end
 
%% =======================
% PASSO 8: CÁLCULO DAS REAÇÕES DE APOIO
tabela_reacoes_apoio = calcular_reacoes_apoio(...
    matriz_rigized_global, vetor_forcas_global, tabela_deslocamentos_global);
disp('--- Reações de Apoio ---')
disp(tabela_reacoes_apoio)
%% =======================
% PASSO 9: VISUALIZAÇÃO DA TRELIÇA COLOREDA
sigma_ruptura = 75e6;  % 75 MPa em Pa
plot_trelica(dados, tabela_deformacoes_tensoes, sigma_ruptura);


%% =======================
% FUNÇÃO: PLOT DA TRELIÇA COM CORES POR UTILIZAÇÃO
function plot_trelica(dados, tabela_deformacoes, sigma_ruptura)
    % dados: matriz [n_nos × 10] onde col 2,3 = X,Y
    % tabela_deformacoes: saída de calcular_deformacoes_tensoes
    % sigma_ruptura: em Pa (ex: 75e6)

    % 1) reconstrói a conectividade
    elementos_tbl = readtable('entradas.xlsx', 'Sheet', 'Tabela Elementos');
    conect = gerar_conectividade_do_excel(elementos_tbl);
    n_elem = size(conect, 1);

    % 2) extrai tensões e calcula utilização
    sigma = tabela_deformacoes.("Tensão (Pa)");
    util = sigma ./ sigma_ruptura;

    % 3) identifica o elemento de maior tensão (absoluta)
    [~, idx_max] = max(abs(sigma));

    % 4) separa índices por faixa
    idx_verde    = find(util < 0.50 & (1:n_elem)' ~= idx_max);
    idx_amarelo  = find(util >= 0.50 & util < 0.90 & (1:n_elem)' ~= idx_max);
    idx_vermelho = find(util >= 0.90 & (1:n_elem)' ~= idx_max);

    % 5) abre figura
    figure; hold on;

    % Verde
    for e = idx_verde'
        ni = conect(e,1); nj = conect(e,2);
        plot([dados(ni,2) dados(nj,2)], [dados(ni,3) dados(nj,3)], ...
             '-', 'Color',[0 1 0], 'LineWidth',2);
    end
    % Amarelo
    for e = idx_amarelo'
        ni = conect(e,1); nj = conect(e,2);
        plot([dados(ni,2) dados(nj,2)], [dados(ni,3) dados(nj,3)], ...
             '-', 'Color',[1 1 0], 'LineWidth',2);
    end
    % Vermelho
    for e = idx_vermelho'
        ni = conect(e,1); nj = conect(e,2);
        plot([dados(ni,2) dados(nj,2)], [dados(ni,3) dados(nj,3)], ...
             '-', 'Color',[1 0 0], 'LineWidth',2);
    end
    % Roxo - Maior tensão
    ni = conect(idx_max,1); nj = conect(idx_max,2);
    plot([dados(ni,2) dados(nj,2)], [dados(ni,3) dados(nj,3)], ...
         '-', 'Color',[0.5 0 0.5], 'LineWidth',3);  % Roxo

    % 6) adiciona nós
    scatter(dados(:,2), dados(:,3), 40, 'k', 'filled');

    % 7) configurações finais
    axis equal; grid on;
    xlabel('X (m)'); ylabel('Y (m)');
    title('Treliça colorida por utilização de tensão');

    % Legenda
    h1 = plot(NaN, NaN, '-', 'Color', [0 1 0], 'LineWidth', 2);
    h2 = plot(NaN, NaN, '-', 'Color', [1 1 0], 'LineWidth', 2);
    h3 = plot(NaN, NaN, '-', 'Color', [1 0 0], 'LineWidth', 2);
    h4 = plot(NaN, NaN, '-', 'Color', [0.5 0 0.5], 'LineWidth', 3);
    legend([h1 h2 h3 h4], {'<50 %', '50–90 %', '≥90 %', 'Máxima tensão'}, ...
        'Location', 'best');

    hold off;
end
fprintf("%d", )
