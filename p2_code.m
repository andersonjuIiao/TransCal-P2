
% LEITURA DOS DADOS DO EXCEL
dados = readmatrix('entradas.xlsx');  % [Nó, X, Y, E, A, Tipo de apoio]
dados = dados(:, 1:6);  % Garante apenas 6 colunas úteis

%% =======================
% GERAÇÃO DAS PROPRIEDADES DOS ELEMENTOS

tabela = propriedades_elementos_conectividade(dados);

%% =======================
% GERAÇÃO DAS MATRIZES DE RIGIDEZ LOCAIS
matrizes_rigidez = matriz_rigized(tabela);

%% =======================
% EXIBIÇÃO DE TABELAS NO CONSOLE
disp(tabela)
disp(matrizes_rigidez)

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
        case 3  % Engaste
            plot(x, y, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'green');
            text(x - 0.05, y, 'Engaste', 'FontSize', 9);
        otherwise
            warning('Tipo de apoio inválido. Use 1 = Pino, 2 = Rolete, 3 = Engaste.');
    end
end
