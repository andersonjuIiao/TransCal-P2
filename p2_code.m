dados = readmatrix('entradas.xlsx');  % Lê sem se preocupar com nomes de colunas

% Verifica se há pelo menos 3 colunas
if size(dados, 2) >= 3
    for i = 1:size(dados, 1)  % Percorre todas as linhas
        % Verifica se algum valor da linha é nulo (NaN)
        if any(isnan(dados(i, :)))
            disp('Valor nulo encontrado, parando a execução.');
            break;
        end
        
        % Extrai os valores de a, b, c para a linha atual
        a = dados(i, 1);
        b = dados(i, 2);
        c = dados(i, 3);

        % Chamada da função
        [s, p, m] = solucao_sistema_de_equacoes(a, b, c);

        % Exibição dos resultados
        fprintf('Linha %d:\n', i);
        fprintf('Soma: %.2f\n', s);
        fprintf('Produto: %.2f\n', p);
        fprintf('Média: %.2f\n\n', m);
    end
else
    disp('Erro: Arquivo não contém dados suficientes (pelo menos 1 linha e 3 colunas).');
end

% Função no final do arquivo
function [soma, produto, media] = solucao_sistema_de_equacoes(a, b, c)
    soma = a + b + c;
    produto = a * b * c;
    media = (a + b + c) / 3;
end
