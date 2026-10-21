CREATE TABLE environment_test (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message TEXT NOT NULL
);

INSERT INTO environment_test (message)
VALUES ('Database environment works');
