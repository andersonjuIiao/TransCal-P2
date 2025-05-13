


function [soma, produto, media] = solucao_sistema_de_equacoes(a, b, c)
    % operacoes_basicas - Realiza operações simples com três números
    %
    % Sintaxe:
    %   [soma, produto, media] = operacoes_basicas(a, b, c)
    %
    % Entradas:
    %   a, b, c - Números reais
    %
    % Saídas:
    %   soma - Soma dos três números
    %   produto - Produto dos três números
    %   media - Média aritmética dos três números

    soma = a + b + c;
    produto = a * b * c;
    media = (a + b + c) / 3;
end

% Chamada da função
[s, p, m] = solucao_sistema_de_equacoes(2, 4, 6);

% Exibição dos resultados
fprintf('Soma: %.2f\n', s);
fprintf('Produto: %.2f\n', p);
fprintf('Média: %.2f\n', m);