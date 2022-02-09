use policlinici;

DROP TRIGGER IF EXISTS creare_istoric;
DELIMITER //
CREATE TRIGGER creare_istoric AFTER INSERT ON Programari_pacient
FOR EACH ROW BEGIN
	SET @nume := NULL;
    SET @prenume := NULL;
    SET @nume := (SELECT i.nume_pacient -- vedem daca exista un istoric deja facut adica vom cauta numele si prenumele
    FROM Istorice AS i
    WHERE nume_pacient LIKE i.nume_pacient);
    
    SET @prenume := (SELECT i.prenume_pacient
    FROM Istorice AS i
    WHERE prenume_pacient LIKE i.prenume_pacient);
    
    IF (@nume IS NULL OR @prenume IS NULL) THEN   -- daca nu s-au gasit, atunci introducem in tsorice
		INSERT INTO Istorice (nume_pacient, prenume_pacient, ziua) VALUES (new.nume_pacient, new.prenume_pacient, new.ziua);
    END IF;
    
    SET @istoric := (SELECT id_istoric
    FROM Istorice as i
    WHERE i.nume_pacient LIKE nume_pacient AND prenume_pacient LIKE i.prenume_pacient);
    -- raportul se va crea automat cu crearea unei programari
    INSERT INTO Rapoarte_programare (nume_pacient, prenume_pacient, ziua, rezultat, id_istoric, cnp_medic_rec) VALUES (new.nume_pacient, new.prenume_pacient, new.ziua, 'Pozitiv', @istoric, new.CNP_medic);
END; //
DELIMITER ;

DROP TRIGGER IF EXISTS stergere_raport;
DELIMITER //
CREATE TRIGGER stergere_raport AFTER DELETE ON Programari_pacient -- daca se sterge o programare trebuie sa se stearga automat si raportul ei
FOR EACH ROW BEGIN
	DELETE FROM Rapoarte_programare
    WHERE nume_pacient LIKE old.nume_pacient AND prenume_pacient LIKE old.prenume_pacient;
END; //
DELIMITER ;

DROP TRIGGER IF EXISTS repartizare_pe_cabinet;
DELIMITER //
CREATE TRIGGER repartizare_pe_cabinet AFTER INSERT ON Specialitati
	FOR EACH ROW BEGIN
    
		DECLARE unitatea VARCHAR(100);
		DECLARE done BOOLEAN DEFAULT FALSE;
		DECLARE cursorul CURSOR FOR (SELECT unitate_medicala
									FROM Orare_generice
									WHERE new.CNP_medic LIKE CNP_utilizator);
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; -- parcurgem toate unitatile medicale la care este doctorul angajat si 
        -- creeam reaprtizarea catre cabinetul existent cu specializarea introdusa 
		OPEN cursorul;
		parcurgere_unitati: LOOP
			FETCH cursorul INTO unitatea;
			IF done THEN
				LEAVE parcurgere_unitati;
			END IF;
            SET @id_cab := NULL;
			SET @id_cab := (SELECT id_cabinet -- verificam daca exista cabinetul
						FROM Cabinete
						WHERE unitatea LIKE unitate_medicala
						AND NEW.denumire LIKE specialitate);
			IF (@id_cab IS NOT NULL) THEN -- iar daca exista intorduem
				SET @ok := NULL;
                SET @ok := (SELECT id_repartizare -- doar daca nu a fost introdusa deja repartizarea
							FROM Repartizare
                            WHERE id_cabinet = @id_cab AND CNP_medic = new.CNP_medic);
				IF (@ok IS NULL) THEN
					INSERT INTO Repartizare (id_cabinet, CNP_medic) VALUES (@id_cab, new.CNP_medic);
				END IF;
			END IF;
		END LOOP;
	CLOSE cursorul;
END; //
DELIMITER ;

DROP TRIGGER IF EXISTS validare_inserare_serviciu;
DELIMITER \\
CREATE TRIGGER validare_inserare_serviciu BEFORE INSERT ON Servicii_medicale
FOR EACH ROW BEGIN
	SET @ok := NULL;
	SET @ok := (SELECT id_specialitate -- verificam daca doctorul are specializarea medicala potrivita
				FROM Specialitati AS s
                WHERE s.CNP_medic = new.CNP_medic
                AND denumire LIKE new.specialitate);
    IF (@ok IS NOT NULL) THEN
		SET @ok2 := (SELECT id_competenta -- si daca are competentele necesare
					FROM Competente as c
                    WHERE c.CNP_medic = new.CNP_medic
                    AND denumire LIKE new.competente);
		IF (@ok2 IS NULL) THEN
			SET NEW.denumire = NULL;
		END IF;
	ELSE
		SET NEW.denumire = NULL;
	END IF;
END; \\
DELIMITER ;
