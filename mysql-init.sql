-- Grant privileges to root from any host
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Update root user host permissions
UPDATE mysql.user SET host='%' WHERE user='root' AND host='localhost';

FLUSH PRIVILEGES;