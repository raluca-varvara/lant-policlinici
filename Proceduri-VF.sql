USE Policlinici;

DROP PROCEDURE IF EXISTS stabilire_concediu;
DELIMITER //
CREATE PROCEDURE stabilire_concediu (Nume VARCHAR(255), Prenume VARCHAR(255), data_inc DATE, data_sf DATE)
BEGIN
    SET @n := (SELECT u.nume
				FROM Utilizatori AS u
                WHERE u.nume LIKE Nume
                LIMIT 1);
	SET @p := (SELECT u.prenume
				FROM Utilizatori AS u
                WHERE u.prenume LIKE Prenume
                LIMIT 1);
	IF (@n IS NOT NULL AND @p IS NOT NULL) THEN -- verificam prima oara daca exista un utilizator cu acest nume 
		IF (data_inc <= data_sf) THEN
			SET @m := (SELECT functie
						FROM Utilizatori AS u
                        WHERE u.nume LIKE Nume AND u.prenume LIKE Prenume);
			SET @ok := 1;
			IF (@m LIKE 'medic') THEN -- daca este medic trebuie sa verificam sa nu aiba o programare in data in care vrea sa isi ia concediu
				SET @programari := (SELECT COUNT(p.id_programare)
									FROM Programari_pacient AS p, Utilizatori AS u
                                    WHERE p.CNP_medic = u.CNP
                                    AND ziua BETWEEN data_inc AND data_sf);
				IF (@programari <> '0') THEN
					SELECT @ok := 0;
				END IF;
            END IF;
			IF (@ok = 1) THEN -- daca nu are programare sau daca nu e  medic atunci introducem in tabela de concedii
				SET @c := (SELECT u.CNP
							FROM Utilizatori AS u
							WHERE u.nume LIKE Nume AND u.prenume LIKE Prenume);
				INSERT INTO Concedii (CNP_utilizator, data_inceput, data_sfarsit) VALUES (@c, data_inc, data_sf);
			END IF;
        END IF;
    END IF;
END; //
DELIMITER ;

drop procedure IF EXISTS add_new_orar_generic;
delimiter //
create procedure add_new_orar_generic(CNP_util BIGINT(13), zi VARCHAR(100), ora_inceput TIME, ora_sfarsit TIME, unitate_medicala VARCHAR(100), OUT Rezultat INT)
begin
	set @ora_i = null;
    set @ora_f = null; -- pentru a ii atribui un orar generic unui utilizator trebuie sa verificam daca se incadreaza in programul policlinicii
    if zi like 'luni' then -- extragem orarul policlinicii din ziua respectiva
		select @ora_i :=programe.luni_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.luni_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
    if zi like 'marti' then
		select @ora_i :=programe.marti_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.marti_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
    if zi like 'miercuri' then
		select @ora_i :=programe.miercuri_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.miercuri_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
     if zi like 'joi' then
		select @ora_i :=programe.joi_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.joi_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
     if zi like 'vineri' then
		select @ora_i :=programe.vineri_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.vineri_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
     if zi like 'sambata' then
		select @ora_i :=programe.sambata_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.sambata_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
     if zi like 'duminica' then
		select @ora_i :=programe.duminica_ora_inceput from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
        select @ora_f :=programe.duminica_ora_sfarsit from programe where programe.id_program like (select id_program from unitati_medicale where denumire like unitate_medicala);
	end if;
    
    if @ora_i is not null and @ora_f is not null then
		if @ora_i<=ora_inceput and @ora_f>=ora_sfarsit then 
			 SET @ok := (SELECT COUNT(id_orar) -- verificam daca nu are deja introdus un orar generic pe ziua respectiva
						FROM Orare_generice AS o
                        WHERE CNP_util LIKE CNP_utilizator AND o.zi LIKE zi AND o.unitate_medicala LIKE unitate_medicala
                        AND (@ora_i<o.ora_sfarsit OR @ora_s<o.ora_inceput));
			IF (@ok = 0) THEN
				INSERT INTO orare_generice (CNP_utilizator, zi, ora_inceput, ora_sfarsit, unitate_medicala)
				VALUES (CNP_util, zi, ora_inceput, ora_sfarsit, unitate_medicala);
				SET Rezultat := 1;
			END IF;
		else
			SET Rezultat := 0;
        END IF;
	else
			SET Rezultat := 0;
    end if;
end //
delimiter ;

DROP PROCEDURE IF EXISTS logare;
DELIMITER \\
CREATE PROCEDURE logare (username BIGINT(13), parola VARCHAR(15), OUT Rezultat INT)
BEGIN
	-- se verifica daca usernameul adica cnp-ul corespunde parolei stocate tuplei respective in tabela de utilizatori
	SET @cont := (SELECT CNP
				FROM Utilizatori
                WHERE username = CNP);
	IF (@cont IS NOT NULL) THEN
		SET @p := (SELECT parola
					FROM Utilizatori
					WHERE CNP = @cont);
		IF (parola LIKE @p) THEN
			SET Rezultat := '1';
		ELSE
			SET Rezultat := '0';
        END IF;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS completare_raport;
DELIMITER \\
CREATE PROCEDURE completare_raport (CNP_cadru_medical BIGINT(13), Raport INT, Campul VARCHAR(255), Textul TEXT, OUT Rezultat INT)
BEGIN
	SET Rezultat := 0;
	SET @parafa := (SELECT cod_parafa
					FROM Rapoarte_programare
                    WHERE Raport = id_raport);
	IF (@parafa IS FALSE OR @parafa IS NULL) THEN
		SET @subsemnatul := (SELECT functie
							FROM Utilizatori
							WHERE CNP = CNP_cadru_medical);
		IF (@subsemnatul LIKE 'medic') THEN
			SET @parafa_medic = (SELECT cod_parafa 
								 FROM medici
							     WHERE CNP_utilizator = CNP_cadru_medical);
			CASE 
            WHEN Campul LIKE 'cod_parafa' THEN
				UPDATE Rapoarte_programare
                SET cod_parafa = @parafa_medic
                WHERE id_raport = Raport;
			WHEN Campul LIKE 'investigatie' THEN
				UPDATE Rapoarte_programare
                SET investigatie = Textul
                WHERE id_raport = Raport;
			END CASE;
            SET Rezultat := 1;
        ELSE
			IF (@subsemnatul LIKE 'asistent medical') THEN
				SET @asis := (SELECT CNP_asistent
							 FROM Rapoarte_programare
                             WHERE id_raport = Raport);
				IF (@asis IS NULL OR @asis = CNP_cadru_medical) THEN
					CASE 
					WHEN Campul LIKE 'rezultat' THEN
						UPDATE Rapoarte_programare
						SET rezultat = TRUE
						WHERE id_raport = Raport;
					WHEN Campul LIKE 'recomandari' THEN
						UPDATE Rapoarte_programare
						SET recomandari = Textul
						WHERE id_raport = Raport;
					WHEN Campul LIKE 'simptome' THEN
						UPDATE Rapoarte_programare
						SET simptome = Textul
						WHERE id_raport = Raport;
					WHEN Campul LIKE 'diagnostic' THEN
						UPDATE Rapoarte_programare
						SET diagnostic = Textul
						WHERE id_raport = Raport;  
					END CASE;
                    
                    IF (@asis IS NULL) THEN
						UPDATE Rapoarte_programare
                        SET CNP_asistent = CNP_cadru_medical
                        WHERE id_raport = Raport;
					END IF;
                    
                    SET Rezultat := 1;
				END IF;
            END IF;
        END IF;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS stergere_serviciu;
DELIMITER \\
CREATE PROCEDURE stergere_serviciu (CNP_cadru_medical BIGINT(13), Serviciu VARCHAR(255), OUT Rezultat INT)
BEGIN
	-- se verifica daca exista la medicul respectiv serviciul care se vrea a sterge si dupa se sterge
	SET Rezultat := 0;
    SET @ok := NULL;
    SET @ok := (SELECT id_serviciu_medical
				FROM Servicii_medicale
				WHERE CNP_medic = CNP_cadru_medical
                AND denumire LIKE Serviciu);
	IF (@ok IS NOT NULL) THEN
		DELETE FROM Servicii_medicale
        WHERE CNP_medic = CNP_cadru_medical AND denumire LIKE Serviciu;
        SET Rezultat := 1;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS adaugare_serviciu;
DELIMITER \\
CREATE PROCEDURE adaugare_serviciu(CNP_cadru_medical BIGINT(13), Serviciu VARCHAR(255), Specialitate VARCHAR(255), Competenta VARCHAR(255), Pret INT, Durata INT, OUT Rezultat INT)
BEGIN
	-- se verifica sa nu existe deja acel serviciu, si daca nu, se insereaza
	SET Rezultat := 0;
    SET @ok := NULL;
    SET @ok := (SELECT id_serviciu_medical
				FROM Servicii_medicale
				WHERE CNP_medic = CNP_cadru_medical
                AND denumire LIKE Serviciu);
	IF (@ok IS NULL) THEN
		INSERT INTO Servicii_medicale (CNP_medic, denumire, specialitate, competente, pret, durata) VALUES (CNP_cadru_medical, Serviciu, Specialitate, Competenta, Pret, Durata);
        SET Rezultat := 1;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS stergere_programare;
DELIMITER \\
CREATE PROCEDURE stergere_programare (Programare INT, Nume VARCHAR(255), Prenume VARCHAR(255), OUT Rezultat INT)
BEGIN
	-- se verifica daca exista programarea respectiva, si daca da, se sterge 
	SET Rezultat := 0;
    SET @ok := (SELECT id_raport
				FROM Programari_pacient
				WHERE id_programare = Programare AND nume_pacient LIKE Nume AND prenume_pacient LIKE Prenume);
	IF (@ok IS NOT NULL) THEN
		DELETE FROM Programari_pacient
		WHERE id_programare = Programare AND nume_pacient LIKE Nume AND prenume_pacient LIKE Prenume;
        SET Rezultat := 1;
	END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS stabilire_ora_final;
DELIMITER //
CREATE PROCEDURE stabilire_ora_final (ora_inceput TIME, durata INT, OUT ora_final TIME)
BEGIN
	-- aceasta este procedura care calculeaza ora de final a programarii
	SET @dur := (SELECT SEC_TO_TIME(durata*60));
	SET @dur := ADDTIME(ora_inceput, @dur);
	SET ora_final := @dur; 
END; //
DELIMITER ;

DROP PROCEDURE IF EXISTS creare_programare;
DELIMITER \\
CREATE PROCEDURE creare_programare (Nume_pacient VARCHAR(255), Prenume_pacient VARCHAR(255), Nume_medic VARCHAR(255), Prenume_medic VARCHAR(255), zi DATE,
 timpul TIME, serv VARCHAR(255), Unit VARCHAR(255), OUT Rezultat INT)
BEGIN
	SET Rezultat := 0;
    SET @c := (SELECT CNP
				FROM Utilizatori
				WHERE nume LIKE Nume_medic AND prenume LIKE Prenume_medic);
    SET @dur := (SELECT durata
				FROM Servicii_medicale
				WHERE denumire LIKE serv);
    SET @final_prog := NULL;
    CALL stabilire_ora_final (timpul, @dur, @final_prog);
    
    SET @dur := (SELECT durata #isi pierde valoarea dupa apelul procedurii de sus (habar nu am de ce) si dadea eroare la INSERT
				FROM Servicii_medicale
				WHERE denumire LIKE serv);
	
    IF (zi >= CURRENT_DATE()) THEN
		
		SET @ok := NULL;
		SET @ok := (SELECT id_concediu
					FROM Concedii
                    WHERE zi BETWEEN data_inceput AND data_sfarsit AND
                    CNP_utilizator = @c);
		IF (@ok IS NULL) THEN
			SET @orar_specific := NULL;
            SET @orar_generic := NULL;
            
            SET @orar_specific := (SELECT id_orar
									FROM Orare_specifice AS o
									WHERE @c = o.CNP_utilizator AND o.unitate_medicala LIKE Unit AND zi = o.zi AND
                                    timpul BETWEEN o.ora_inceput AND o.ora_sfarsit
                                    AND @final_prog <= o.ora_sfarsit);
			SET @ziua_no := DAYOFWEEK(zi);
				CASE 
					WHEN @ziua_no = 2 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'luni' 
                                             AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
					WHEN @ziua_no = 3 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'marti' 
                                            AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
                    WHEN @ziua_no = 4 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'miercuri' 
                                             AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
                    WHEN @ziua_no = 5 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'joi' 
                                            AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
                    WHEN @ziua_no = 6 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'vineri' 
                                             AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
                    WHEN @ziua_no = 7 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'sambata' 
                                             AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
                    WHEN @ziua_no = 1 THEN
						SET @orar_generic := (SELECT id_orar
											FROM Orare_generice AS o
                                            WHERE @c = CNP_utilizator AND o.zi LIKE 'duminica' 
                                            AND unitate_medicala LIKE Unit AND timpul >= ora_inceput AND timpul <= ora_sfarsit AND @final_prog <= ora_sfarsit);
				END CASE;
			IF (@orar_specific IS NOT NULL OR @orar_generic IS NOT NULL) THEN
				SET @ok2 := NULL;
				SET @ok2 := (SELECT id_serviciu_medical
						FROM Servicii_medicale
						WHERE CNP_medic = @c AND denumire LIKE serv);
				IF (@ok2 IS NOT NULL) THEN
					SET Rezultat := 1;
					INSERT INTO Programari_pacient (nume_pacient, prenume_pacient, CNP_medic, ziua, ora, serviciu, durata, unitate_medicala) VALUES (Nume_pacient, Prenume_pacient, @c, zi, timpul, serv, @dur, Unit);
				END IF;
			END IF;
        END IF;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS afisare_date_angajat;
DELIMITER \\
CREATE PROCEDURE afisare_date_angajat (Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR (255), Func VARCHAR(100), OUT Rezultat INT)
BEGIN
	-- se cauta cnp-ul si daca exista se selecteaza toate datele din tabela de utilizatori pentru cnp-ul respectiv
	SET Rezultat := 0;
	SET @C := NULL;
	SET @C := (SELECT CNP
				FROM Utilizatori
                WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat
                AND Func LIKE functie);
	IF (@C IS NOT NULL) THEN
		SET Rezultat := 1;
        SELECT *
        FROM Utilizatori
        WHERE CNP = @c;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS calculare_salariu;
DELIMITER \\
CREATE PROCEDURE calculare_salariu (Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR(255), Luna INT, OUT Salariu BIGINT)
BEGIN
	SET @func := NULL;
    SET @func := (SELECT functie
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
	SET @c := NULL;
    SET @c := (SELECT CNP
				FROM Utilizatori
				WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
	IF (@func IS NOT NULL AND @func <> 'medic') THEN -- aici este salariul calculat pentru angajatii care nu sunt medici
		SET @data_incepere := (SELECT MIN(data_inceput) -- calculam perioada in care exista concedii
						   FROM Concedii
                           WHERE CNP_utilizator = @c AND MONTH(data_inceput) = Luna);
		SET @data_sf := (SELECT MAX(data_sfarsit)
						   FROM Concedii
                           WHERE CNP_utilizator = @c AND MONTH(data_inceput) = Luna);
		SET @nr_ore_lipsa := 0; -- vom calcula numarul de ore lipsa, deoarece concediul nu este platit asa ca le vom scade din numarul dde ore din contract
		WHILE @data_incepere <= @data_sf DO
			SET @ok := (SELECT id_concediu
						FROM Concedii
                        WHERE @data_incepere BETWEEN data_inceput AND data_sfarsit
                        AND CNP_utilizator = @c);
			IF (@ok IS NOT NULL) THEN -- daca exista concediu in ziua respectiva atunci cautam cate ore ar fi lucrat in ziua respectiva dupa ziua saptamanii
				SET @nr := (SELECT SUM(TIME_TO_SEC(TIMEDIFF(ora_sfarsit, ora_inceput)) / 3600)
							FROM Orare_generice
                            WHERE DAYOFWEEK(@data_incepere) = ziua_saptamanii(zi)
                            AND CNP_utilizator = @c);
				SET @nr_ore_lipsa := @nr_ore_lipsa + @nr;
			END IF;
            SET @data_incepere := DATE_ADD(@data_incepere, INTERVAL 1 DAY); 
		END WHILE;
        SET @ore := (SELECT nr_ore
					FROM Utilizatori
					WHERE CNP = @c);
		SET @sal := (SELECT salar_neg
					FROM Utilizatori
                    WHERE CNP = @c);
        SET Salariu := (@ore - @nr_ore_lipsa) * @sal;
	ELSE
		IF (@func IS NOT NULL OR @func LIKE 'medic') THEN -- daca este medic numai insumam preturile consultatiilor sale
			set @s := 0;
			set @s := (select SUM(pret) from programari_pacient as p join servicii_medicale as s where p.serviciu like s.denumire
					and s.CNP_medic = @c and month(ziua) = Luna);
		END IF;
		SET Salariu := @s;
    END IF;
END; \\
DELIMITER ;

DROP FUNCTION IF EXISTS ziua_saptamanii;
DELIMITER \\
CREATE FUNCTION ziua_saptamanii (Ziua VARCHAR(255))
RETURNS INT
DETERMINISTIC
	BEGIN
		-- aceasta este o functie care returneaza a cata zi din saptamana este un varchar pe care il introducem, adica numele zilelor dar in limba romana
		IF (Ziua LIKE 'luni') THEN
			RETURN 2;
		END IF;
        IF (Ziua LIKE 'marti') THEN
			RETURN 3;
		END IF;
        IF (Ziua LIKE 'miercuri') THEN
			RETURN 4;
		END IF;
        IF (Ziua LIKE 'joi') THEN
			RETURN 5;
		END IF;
        IF (Ziua LIKE 'vineri') THEN
			RETURN 6;
		END IF;
        IF (Ziua LIKE 'sambata') THEN
			RETURN 7;
		END IF;
        IF (Ziua LIKE 'duminica') THEN
			RETURN 1;
		END IF;
END; \\
DELIMITER ;
 

DROP PROCEDURE IF EXISTS profit_medic_policlinica;
DELIMITER \\
CREATE PROCEDURE profit_medic_policlinica (Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR(255), Nume_policlinica VARCHAR(255), Luna INT, OUT Profit BIGINT)
BEGIN
	-- calculam totalul pe care se aduna din toate consultatiile medicului de la o anumita unitate medicala si extragem procentul pe care il pastreaza pentru el
	SET @func := NULL;
    SET @func := (SELECT functie
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
                 
	SET @c := null;
    SET @c := (SELECT CNP
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
                 
	SET @p := null;
    SET @p :=(select procent_adaugat from medici where CNP_utilizator =@c);
	IF (@func IS NOT NULL OR @func = 'medic') THEN
		set @s := 0;
        set @s := (select SUM(pret) from programari_pacient as p join servicii_medicale as s where p.serviciu like s.denumire
					and s.CNP_medic = @c and month(ziua) = Luna and p.unitate_medicala like Nume_policlinica); 
    END IF;
    SET Profit := @s - @s*@p/100; -- aceasta este formula profitului adus policlinicii, scaem din total procentul pe care il pastreaza
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS profit_specialitate_policlinica;
DELIMITER \\
CREATE PROCEDURE profit_specialitate_policlinica (nume_specialitate VARCHAR(255), Nume_policlinica VARCHAR(255), Luna INT, OUT Profit BIGINT)
BEGIN
	-- se foloseste aceiasi formula ca mai sus dar de aceasta data vor fi mai multi medici asa ca vom face join pe cnp ul medicului cu tabela de medici si vom extrace de acolo procentul
	SET @p :=null;
    SET @p := (select SUM(pret-pret*procent_adaugat/100) from programari_pacient as p join servicii_medicale as s on p.serviciu like s.denumire
			join medici as m on s.CNP_medic = m.CNP_utilizator where s.specialitate like nume_specialitate and p.unitate_medicala like Nume_policlinica
            and month(p.ziua) = Luna);
	SET Profit := @p;
END; \\
DELIMITER ;


DROP PROCEDURE IF EXISTS afisare_program_lunar;
DELIMITER \\
CREATE PROCEDURE afisare_program_lunar(Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR(255), Nume_policlinica VARCHAR(255), Luna INT, An INT)
BEGIN
	SET @c := null;
    SET @c := (SELECT CNP
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
	SET @data_in:= concat(An,'-0',Luna,'-','01'); -- cream prima data din luna si anul care ni se dau
    SET @data_sf :=LAST_DAY(@data_in); -- si extragem si ulima zi din luna pentru a stii unde ne oprim cu parcurgea lunii

    WHILE @data_in <= @data_sf
    DO
		SET @concediu:=(SELECT id_concediu from concedii where CNP_utilizator =@c and @data_in>=data_inceput And @data_in<=data_sfarsit); -- vedem daca are concediu in ziua respectiva
        SET @specif := (SELECT id_orar from orare_specifice where  CNP_utilizator =@c and @data_in like zi and unitate_medicala like Nume_policlinica); -- vedem daca exista orar specific in ziua respectiva
        --  verificam daca exista concediu in acea zi sau program specific, concediul are prioritate, dupa programul specific si de abia dupa cel normal
        IF (@concediu <> null) then
			SELECT concat(Nume_angajat,' ',Prenume_angajat, 'are concediu');
		ELSE
			IF (@specif <> null) then
				SELECT zi as Ziua, ora_inceput, ora_sfarsit from orare_specifice where id_orar = @specif;
            ELSE
				SELECT @data_in AS Ziua, ora_inceput, ora_sfarsit 
                FROM orare_generice 
                WHERE CNP_utilizator = @c AND ziua_saptamanii(zi)=dayofweek(@data_in);
            END IF;
        END IF;
    SET @data_in :=DATE_ADD(@data_in, INTERVAL 1 day);
    END WHILE;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS afisare_concedii;
DELIMITER \\
CREATE PROCEDURE afisare_concedii (Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR(255))
BEGIN
	SET @c := null;
    SET @c := (SELECT CNP
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
	SET @data_inceput:=DATE_ADD(CURRENT_DATE(), INTERVAL(-WEEKDAY(CURRENT_DATE())) DAY); -- cream prima zi in saptamana curenta
    SET @i:=0;
    while(@i<7)
    DO
		SELECT * from concedii where @data_inceput=data_inceput and CNP_utilizator = @c;
		SET @data_inceput:=DATE_ADD(@data_inceput, INTERVAL 1 day);
        set @i:=@i+1;
    END WHILE;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS afisare_orar_saptamanal;
DELIMITER \\
CREATE PROCEDURE afisare_orar_saptamanal (Nume_angajat VARCHAR(255), Prenume_angajat VARCHAR(255), Nume_policlinica VARCHAR(255))
BEGIN
	SET @data_inceput:=DATE_ADD(CURRENT_DATE(), INTERVAL(-WEEKDAY(CURRENT_DATE())) DAY); -- cream prima zi din saptamana curenta
    SET @i:=0;
    SET @c := null;
    SET @c := (SELECT CNP
				 FROM Utilizatori
                 WHERE nume LIKE Nume_angajat AND prenume LIKE Prenume_angajat);
    while(@i<7)
    DO
		SET @specif:=null; -- daca are orar specific afisam orarul specific, daca nu pe cel normal
		SET @specif := (SELECT id_orar from orare_specifice where  CNP_utilizator =@c and @data_inceput like zi and unitate_medicala like Nume_policlinica);
		IF (@specif<>null) THEN
			select * from orare_specifice where id_orar=@specif;
		else
			select * from orare_generice where CNP_utilizator = @c and ziua_saptamanii(zi)=dayofweek(@data_inceput)and unitate_medicala like Nume_policlinica; 
		end if;
		SET @data_inceput:=DATE_ADD(@data_inceput, INTERVAL 1 day);
        set @i:=@i+1;
    END WHILE;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS profit_policlinica;
DELIMITER \\
CREATE PROCEDURE profit_policlinica(Nume_policlinica VARCHAR(255), Luna INT, An INT, OUT Salarii BIGINT)
BEGIN
	DECLARE utilizatorul VARCHAR(100);
		DECLARE done BOOLEAN DEFAULT FALSE;
		DECLARE cursorul CURSOR FOR (SELECT CNP
									FROM Utilizatori);
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
        OPEN cursorul;
        BEGIN
        SET @salarii:=0;
		parcurgere_utilizator: LOOP
			FETCH cursorul INTO utilizatorul;
			IF done THEN
				LEAVE parcurgere_utilizator;
			END IF;
			SET @polic := (SELECT COUNT(id_orar) from orare_generice where CNP_utilizator = utilizatorul and unitate_medicala like Nume_policlinica);
            IF(@polic <> 0) THEN
				SET @nume := (select nume from utilizatori where CNP = utilizatorul);
                SET @prenume := (select prenume from utilizatori where CNP = utilizatorul);
                SET @aux:=null;
                call calculare_salariu(@nume,@prenume, Luna, @aux);
                SET @salarii:=@salarii-@aux;
                SET @e_medic:=(select functie from utilizatori where CNP = utilizatorul);
                IF (@e_medic like 'medic') THEN
					SET @aux1:=null;
                    call profit_medic_policlinica(@nume, @prenume,Nume_policlinica,Luna,@aux1);
                    SET @salarii:=@salarii+@aux1;
                END IF;
            END IF;
		END LOOP;
        SET Salarii := @salarii;
        END;
	CLOSE cursorul;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS stergere_utilizator;
DELIMITER \\
CREATE PROCEDURE stergere_utilizator (Nume VARCHAR(255), Prenume VARCHAR(255), CNP_modificator BIGINT(13), OUT Rezultat INT)
BEGIN
	SET @c := (SELECT CNP
				FROM Utilizatori AS u
                WHERE u.nume LIKE Nume AND u.prenume LIKE Prenume);
	#ne asiguram ca exista persoane pe care dorim sa o stergem
	IF (@c IS NOT NULL) THEN
    	SET @tipul := (SELECT tip
				FROM Utilizatori
                WHERE CNP_modificator = CNP);
		SET @tipul_sters := (SELECT tip
						FROM Utilizatori AS u
						WHERE u.prenume LIKE Prenume AND u.nume LIKE Nume);
		#verificam relatia de subordonare dintre cele 2 tipuri de utilizatori
		IF (@tipul LIKE 'super-administrator' OR (@tipul LIKE 'administrator' AND @tipul_sters LIKE 'angajat')) THEN
			SET Rezultat := 1;
            SET foreign_key_checks = 0; #pentru a ignora key-ile straine si a sterge fara probleme
            DELETE FROM Utilizatori
            WHERE CNP = @c;
            SET foreign_key_checks = 1; #trebuie sa readucem la forma initiala kei-ile straine pentru a nu cauza daune bazei de date
        ELSE
			SET Rezultat := 0;
		END IF;
	ELSE
		SEt Rezultat := 0;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS creare_utilizator;
DELIMITER \\
CREATE PROCEDURE creare_utilizator(CNP_utilizator BIGINT(13), Nume VARCHAR(255), Prenume VARCHAR(255), adresa VARCHAR(255),
 nr_telefon VARCHAR(11), email VARCHAR(255), IBAN VARCHAR(255), nr_contract BIGINT (10), data_angajarii DATE, tip VARCHAR(255), functie VARCHAR(100), salar_neg FLOAT(7,2),
 nr_ore INT(3), parola VARCHAR(15), CNP_modificator BIGINT(13), OUT Rezultat VARCHAR(200))
BEGIN
	SET @ok := NULL;
	SET @ok := (SELECT u.CNP
				FROM Utilizatori AS u
                WHERE u.nume LIKE Nume AND u.prenume LIKE Prenume);
	#verificam sa nu existe utilizatorul ce doreste sa fie introdus
	IF (@ok IS NULL) THEN
    #extragem tipul persoanei care doreste introducerea
		SET @tipul := (SELECT u.tip
				FROM Utilizatori as u
                WHERE CNP_modificator = u.CNP);
		#asiguram ierarhia manipularii datelor prin atributul de tip
		IF (@tipul LIKE 'super-administrator' OR (@tipul LIKE 'administrator' AND tip LIKE 'angajat')) THEN
			SET Rezultat := 1;
            #introducerea propri-zisa
			INSERT INTO Utilizatori (CNP, nume, prenume, adresa, nr_telefon, email, IBAN, nr_contract, data_angajarii, tip, functie, salar_neg, nr_ore, parola) 
			VALUES (CNP_utilizator, Nume, Prenume, adresa, nr_telefon, email, IBAN, nr_contract, data_angajarii, tip, functie, salar_neg, nr_ore, parola);
		ELSE
			SET Rezultat := @tipul;
		END IF;
	ELSE
		SET Rezultat := 0;
    END IF;
END; \\
DELIMITER ;

DROP PROCEDURE IF EXISTS medici_dupa_serviciu;
DELIMITER \\
CREATE PROCEDURE medici_dupa_serviciu (denumireServiciu VARCHAR(255))
BEGIN
	SELECT CONCAT(u.nume, ' ', u.prenume) AS nume_prenume_medic
	FROM servicii_medicale as s join utilizatori as u on(s.CNP_medic = u.CNP)
	WHERE denumireServiciu = s.denumire;
END; \\
DELIMITER \\

DROP PROCEDURE IF EXISTS pret_dupa_serviciu_si_medic;
DELIMITER \\
CREATE PROCEDURE pret_dupa_serviciu_si_medic(denumireServiciu VARCHAR(255), nume_medic VARCHAR(255), prenume_medic VARCHAR(255), OUT rez INT)
BEGIN
	SET @c := (SELECT CNP
				FROM Utilizatori
				WHERE nume LIKE nume_medic AND prenume LIKE prenume_medic);
	SET @pret := (SELECT pret 
				   FROM servicii_medicale
                   WHERE @c = CNP_medic AND denumireServiciu = denumire);
	SET rez := @pret;
END; \\
DELIMITER \\

DROP PROCEDURE IF EXISTS determinare_functie;
DELIMITER \\
CREATE PROCEDURE determinare_functie (username BIGINT(13), parola VARCHAR(15), OUT Functia Varchar(100), OUT Numele VARCHAR(255), OUT Prenumele VARCHAR(255))
BEGIN
	SET Functia := (SELECT functie
				FROM Utilizatori AS u
				WHERE u.CNP = username AND u.parola = parola);
	SET Numele := (SELECT nume
					FROM Utilizatori as u
					WHERE u.CNP = username AND u.parola = parola);
	SET Prenumele := (SELECT prenume
					FROM Utilizatori as u
					WHERE u.CNP = username AND u.parola = parola);
END; \\
DELIMITER \\
