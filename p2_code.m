% Lê os dados do Excel (sem cabeçalhos)
dados = readmatrix('entradas.xlsx');
dados = dados(:, 1:3);  % Usa apenas as colunas: Nó, Coord X, Coord Y

% Chama a função
[f, L, s, c] = solucao_sistema_de_equacoes(dados);
disp('Graus de liberdade encontrados:')
disp(f)
disp('Comprimento L:')
disp(L)
disp('s = sin(theta):')
disp(s)
disp('c = cos(theta):')
disp(c)

% Define a função no final do script (SEM NENHUM COMANDO DEPOIS)
function [graus_liberdade, L, s, c] = solucao_sistema_de_equacoes(dados)
    graus_liberdade = [];
    L = [];
    c = [];
    s = [];
    
    if size(dados, 2) >= 3
        for i = 1:size(dados, 1)
            if any(isnan(dados(i, 2:3)))  % Verifica apenas X e Y
                fprintf('Linha %d tem NaN nos dados principais, parando.\n', i);
                break;
            end

            graus_liberdade(i, :) = [2*i - 1, 2*i];
            fprintf('Nó %d: [%d, %d]\n', i, 2*i - 1, 2*i);

            if i < size(dados, 1) && ~isnan(dados(i+1, 2))
                x1 = dados(i, 2);
                x2 = dados(i+1, 2);
                y1 = dados(i, 3);
                y2 = dados(i+1, 3);
            elseif i > 2
                x1 = dados(i, 2);
                x2 = dados(i-2, 2);
                y1 = dados(i, 3);
                y2 = dados(i-2, 3);
            else
                x1 = NaN; x2 = NaN;
                y1 = NaN; y2 = NaN;
            end

            if ~any(isnan([x1 x2 y1 y2]))
                L(i, 1) = sqrt((x2 - x1)^2 + (y2 - y1)^2);
                s(i, 1) = (y2 - y1) / L(i);
                c(i, 1) = (x2 - x1) / L(i);
            else
                L(i, 1) = NaN;
                s(i, 1) = NaN;
                c(i, 1) = NaN;
            end
        end
    else
        disp('Erro: Arquivo não contém dados suficientes (pelo menos 1 linha e 3 colunas).');
    end
end
