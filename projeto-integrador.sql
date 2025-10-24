CREATE OR REPLACE PACKAGE pkg_gestao_function IS
  PROCEDURE inserir_funcionario(
    p_id_func IN funcionarios.id_func%TYPE,
    p_nome IN funcionarios.nome%TYPE,
    p_salario IN funcionarios.salario%TYPE,
    p_data_admissao IN funcionarios.data_admissao%TYPE,
    p_departamento IN funcionarios.departamento%TYPE
    );
  PROCEDURE aumenta_salario(p_id_func IN funcionarios.id_func%TYPE, percentual IN NUMBER);
  FUNCTION tempo_casa(p_id_func IN funcionarios.id_func%TYPE) RETURN NUMBER;
  PROCEDURE lista_func_por_departamento(p_departamento IN funcionarios.departamento%TYPE);
END pkg_gestao_function;

CREATE OR REPLACE PACKAGE BODY pkg_gestao_function IS
    PROCEDURE inserir_funcionario(
        p_id_func IN funcionarios.id_func%TYPE,
        p_nome IN funcionarios.nome%TYPE,
        p_salario IN funcionarios.salario%TYPE,
        p_data_admissao IN funcionarios.data_admissao%TYPE,
        p_departamento IN funcionarios.departamento%TYPE
    ) IS
    BEGIN
    INSERT INTO funcionarios (id_func, nome, salario, data_admissao, departamento)
    VALUES (p_id_func, p_nome, p_salario, p_data_admissao, p_departamento);

    DBMS_OUTPUT.PUT_LINE('Funcionário inserido com sucesso: ' || p_nome);

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20006, 'Funcionário com este ID já existe.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20007, 'Erro ao inserir funcionário: ' || SQLERRM);
    END inserir_funcionario;

    PROCEDURE aumenta_salario(
        p_id_func IN funcionarios.id_func%TYPE,
        percentual IN NUMBER
    ) IS
    BEGIN
        UPDATE funcionarios
        SET salario = salario * (1 + percentual / 100)
        WHERE id_func = p_id_func;
        
        IF SQL%ROWCOUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Nenhum registro encontrado.');
        ELSE 
            DBMS_OUTPUT.PUT_LINE('Salario atualizado para funcionario com identificador: ' || p_id_func);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002, 'Erro ao atualizar salário: ' || SQLERRM);
    END aumenta_salario;

    FUNCTION tempo_casa(
        p_id_func IN funcionarios.id_func%TYPE
    ) RETURN NUMBER IS
        v_tempo NUMBER;
    BEGIN
        SELECT ROUND(MONTHS_BETWEEN(SYSDATE, data_admissao) / 12, 2)
        INTO v_tempo
        FROM funcionarios
        WHERE id_func = p_id_func;

        RETURN v_tempo;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN 
            DBMS_OUTPUT.PUT_LINE('Nenhum registro encontrado.');
            RETURN NULL;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Erro ao calcular tempo de casa: ' || SQLERRM);
    END tempo_casa;

    PROCEDURE lista_func_por_departamento(
        p_departamento IN funcionarios.departamento%TYPE
    ) IS
        CURSOR c_func_depto IS
            SELECT id_func, nome, salario, data_admissao
            FROM funcionarios
            WHERE LOWER(departamento) = LOWER(p_departamento);

        v_id_func funcionarios.id_func%TYPE;
        v_nome funcionarios.nome%TYPE;
        v_salario funcionarios.salario%TYPE;
        v_data_admissao funcionarios.data_admissao%TYPE;
        v_encontrou BOOLEAN := FALSE;
    BEGIN
        OPEN c_func_depto;
        LOOP
            FETCH c_func_depto INTO v_id_func, v_nome, v_salario, v_data_admissao;
            EXIT WHEN c_func_depto%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE('ID: ' || v_id_func || 
                                 ', Nome: ' || v_nome || 
                                 ', Salário: ' || v_salario || 
                                 ', Admissão: ' || TO_CHAR(v_data_admissao, 'DD/MM/YYYY'));
        END LOOP;
        CLOSE c_func_depto;


    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Erro ao listar funcionários: ' || SQLERRM);
    END lista_func_por_departamento;

END pkg_gestao_function;

-- Triggers
CREATE OR REPLACE TRIGGER trg_valida_aumento_salario
BEFORE UPDATE OF salario ON funcionarios
FOR EACH ROW
BEGIN
    IF :NEW.salario < :OLD.salario THEN
        RAISE_APPLICATION_ERROR(-20010, 'Redução de salário não permitida.');
    END IF;
END;

CREATE OR REPLACE TRIGGER trg_log_aumento_salario
AFTER UPDATE OF salario ON funcionarios
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (acao, id_func)
    VALUES ('AUMENTO_SALARIO', :NEW.id_func);
END;


CREATE OR REPLACE TRIGGER trg_log_troca_departamento
AFTER UPDATE OF departamento ON funcionarios
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (acao, id_func)
    VALUES ('MUDANCA_DEPARTAMENTO', :NEW.id_func);
END;

CREATE OR REPLACE TRIGGER trg_log_insercao_funcionario
AFTER INSERT ON funcionarios
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria (acao, id_func)
    VALUES ('INSERCAO_FUNCIONARIO', :NEW.id_func);
END;

-- Testes package
DECLARE
    v_tempo NUMBER;
BEGIN
    pkg_gestao_function.inserir_funcionario(
    seq_func.NEXTVAL,
    'Camila',
    3000,
    DATE '2022-03-10',
    'RH'
    );
    -- aumentar salario 
    pkg_gestao_function.aumenta_salario(3, 10);
    
    -- calculo tempo de casa
    v_tempo := pkg_gestao_function.tempo_casa(2);
    IF v_tempo > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tempo de casa: ' || v_tempo || ' anos');
    END IF;
    
    pkg_gestao_function.lista_func_por_departamento('TI');
END;


DECLARE
    v_tempo NUMBER;
BEGIN

    -- aumentar salario 
    pkg_gestao_function.aumenta_salario(10, 10);
    
    -- calculo tempo de casa
    v_tempo := pkg_gestao_function.tempo_casa(10);
    IF v_tempo > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tempo de casa: ' || v_tempo || ' anos');
    END IF;
    
    pkg_gestao_function.lista_func_por_departamento('vendas');
END;


-- Testes triggers

UPDATE funcionarios
SET salario = 3000
WHERE id_func = 2;

UPDATE funcionarios
SET departamento = 'vendas'
WHERE id_func = 1;


SELECT * FROM log_auditoria;
