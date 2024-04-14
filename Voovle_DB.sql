-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 01, 2023 at 09:20 PM
-- Server version: 10.4.28-MariaDB
-- PHP Version: 8.2.4

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `gmail_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `Delete_Account` ()   BEGIN
	CALL Last_Login();
	DELETE FROM users
    WHERE UserName = @last;
	DELETE FROM emails
    WHERE Sender = @last OR Recipients = @last;
	DELETE FROM notifications
    WHERE UserName = @last;
	TRUNCATE logins;
    SELECT 'YOUR ACCOUNT HAS BEEN DELETED';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Delete_Email` (IN `pEmailID` INT)   BEGIN
	CALL Last_Login();
	IF EXISTS (SELECT EmailID FROM emails WHERE EmailID = pEmailID AND Sender = @last) THEN
		DELETE FROM emails
        WHERE EmailID = pEmailID AND Sender = @last;
        SELECT 'YOUR EMAIL HAS BEEN DELETED';
	ELSE
		SIGNAL SQLSTATE '45000'
        	SET MESSAGE_TEXT = 'THIS EMAIL DOES NOT EXIST';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Edit_Profile` (IN `pPass` VARCHAR(30), IN `pFirstName` VARCHAR(30), IN `pLastName` VARCHAR(30), IN `pNickName` VARCHAR(30), IN `pID` VARCHAR(10), IN `pAddress` VARCHAR(512), IN `pBirthDate` DATE, IN `pPhoneNumber` VARCHAR(13))   BEGIN
	CALL Last_Login();
	UPDATE users
    SET Pass=SHA1(pPass), FirstName=pFirstName, LastName=pLastName, NickName=pNickName, 						ID=pID, Address=pAddress, BirthDate=pBirthDate, PhoneNumber=pPhoneNumber
    WHERE UserName = @last;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Last_Login` ()   BEGIN
	SET @last = (SELECT UserName FROM logins ORDER BY LoginID DESC LIMIT 1);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Login` (IN `pUserName` VARCHAR(30), IN `pPass` VARCHAR(30))   BEGIN
	IF EXISTS(SELECT * FROM users WHERE UserName = pUserName AND Pass = SHA1(pPass)) THEN
    	INSERT INTO logins(UserName, LoginDate)
        VALUES(pUserName, NOW());
    ELSE
    	SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Wrong UserName or Password';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Logout` ()   BEGIN
	CALL Last_Login();
    TRUNCATE logins;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Register` (IN `pUserName` VARCHAR(30), IN `pPass` VARCHAR(30), IN `pFirstName` VARCHAR(30), IN `pLastName` VARCHAR(30), IN `pNickName` VARCHAR(30), IN `pID` VARCHAR(10), IN `pAddress` VARCHAR(512), IN `pBirthDate` DATE, IN `pPhoneNumber` VARCHAR(13))   BEGIN
	START TRANSACTION;
	IF NOT EXISTS (SELECT * FROM users WHERE UserName=pUserName) THEN
    	IF LENGTH(pUserName) >= 6 AND LENGTH(pPass) >= 6 THEN
    		INSERT INTO users(UserName, Pass, FirstName, LastName, NickName, ID, Address, BirthDate, 				PhoneNumber, CreationDate)
    		VALUES (pUserName, SHA1(pPass), pFirstName, pLastName, pNickName, pID, pAddress, pBirthDate, 				pPhoneNumber, NOW());
    		COMMIT;
		ELSE 
        	ROLLBACK;
        	SIGNAL SQLSTATE '45000'
        		SET MESSAGE_TEXT = 'USERNAME AND PASSWORD MUST CONTAIN ATLEAST 6 CHARACTERS';
        END IF;
    ELSE
    	ROLLBACK;
        IF EXISTS(SELECT * FROM users WHERE UserName=pUserName) THEN
        	SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'This UserName is taken';
        END IF;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Search_Profile` (IN `pUserName` VARCHAR(30))   BEGIN
	IF EXISTS (SELECT * FROM users WHERE UserName = pUserName AND Status = 'Private')THEN
        SET @var = '*';
        SELECT FirstName, LastName, NickName, ID, Address, BirthDate, PhoneNumber
        into @var
        FROM users;
	ELSEIF NOT EXISTS (SELECT * FROM users WHERE UserName=pUserName) THEN
    	SIGNAL SQLSTATE '45000'
        	SET MESSAGE_TEXT = 'THIS PROFILE IS NOT VALID';
	ELSE
    	SELECT FirstName, LastName, NickName, ID, Address, BirthDate, PhoneNumber
        FROM users
        WHERE UserName = pUserName;
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Send_Email` (IN `pRecipients` VARCHAR(512), IN `pCC_Recipients` VARCHAR(512), IN `pSubject` VARCHAR(128), IN `pBody` VARCHAR(512))   BEGIN
	CALL Last_login();
	IF EXISTS (SELECT * FROM users WHERE UserName = pRecipients) THEN
		INSERT INTO emails (Sender, Recipients, CC_Recipients, Subject, Body, SentDate)
		VALUES (@last, pRecipients, pCC_Recipients, pSubject, pBody, NOW());
	ELSE
		SIGNAL SQLSTATE '45000'
        	SET MESSAGE_TEXT = 'RECIPIENT ISNT VALID';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Set_Private` ()   BEGIN	
    CALL Last_Login();
    IF EXISTS (SELECT * FROM users WHERE UserName = 		@last AND Status = 'Private') THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'THIS PROFILE IS ALREADY 			PRIVATE';
	ELSE
		UPDATE users SET Status='private';
        SELECT 'YOUR ACCOUNT IS NOW PRIVATE' AS '';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Set_Public` ()   BEGIN
	CALL Last_Login();
    IF EXISTS (SELECT * FROM users WHERE UserName = 		@last AND Status = 'Public') THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'THIS PROFILE IS ALREADY 			PUBLIC';
	ELSE
		UPDATE users SET Status='Public';
        SELECT 'YOUR ACCOUNT IS NOW PUBLIC' AS '';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Show_Inbox` (IN `pPage` INT)   BEGIN
    CALL Last_Login();
    IF EXISTS (SELECT * FROM emails WHERE Sender = @last) THEN
		SET @page = (pPage-1)*10;
    	SET @sql = CONCAT('SELECT Sender, Subject, Body, SentDate AS Date, Status
                          FROM emails
                          WHERE recipients = @last
                          ORDER BY EmailID DESC LIMIT 10 OFFSET ', @page);
    	PREPARE stmt1 FROM @sql;
    	EXECUTE stmt1;
    	UPDATE emails
        SET Status = 'Seen'
        WHERE Recipients = @last OR CC_Recipients = @last;
	ELSE
    	SELECT 'YOU HAVE NOT RECIEVED ANY EMAILS' AS '';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Show_Notification` (IN `pPage` INT)   BEGIN
	CALL Last_Login();
    IF EXISTS (SELECT * FROM notifications WHERE UserName = @last) THEN
    	SET @page = (pPage-1)*10;
    	SET @sql = CONCAT('SELECT Notification, NotificationDate AS Date
                          FROM notifications
                          WHERE UserName = @last
                          ORDER BY NotificationID DESC LIMIT 10 OFFSET ', @page);
    	PREPARE stmt1 FROM @sql;
    	EXECUTE stmt1;
	ELSE
    	SELECT 'YOU DONT HAVE ANY NOTIFICAIONS';
	END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Show_Sent` (IN `pPage` INT)   BEGIN
	CALL Last_Login();
	IF EXISTS (SELECT * FROM emails WHERE Sender = @last) THEN
    	SET @page = (pPage-1)*10;
    	SET @sql = CONCAT('SELECT EmailID, Recipients AS "To", CC_Recipients, Subject,
                          Body, SentDate AS Date, Status
                          FROM emails
                          WHERE Sender=@last
                          ORDER BY EmailID DESC LIMIT 10 OFFSET ', @page);
    	PREPARE stmt1 FROM @sql;
    	EXECUTE stmt1;
    ELSE 
    	SELECT 'YOU HAVE NOT SENT ANY EMAILS' AS '' ;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `Show_User_Profile` ()   BEGIN
	CALL Last_Login();
	SELECT UserName,Pass AS 'Password', FirstName, 			LastName, NickName, ID, Address, BirthDate, 			PhoneNumber, CreationDate, Status FROM users
    WHERE UserName = @last;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `emails`
--

CREATE TABLE `emails` (
  `EmailID` int(11) NOT NULL,
  `Sender` varchar(41) NOT NULL,
  `Recipients` varchar(512) NOT NULL,
  `CC_Recipients` varchar(128) DEFAULT NULL,
  `Subject` varchar(512) DEFAULT NULL,
  `Body` varchar(512) NOT NULL,
  `SentDate` date NOT NULL,
  `Status` varchar(8) NOT NULL DEFAULT 'Not seen'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `emails`
--

INSERT INTO `emails` (`EmailID`, `Sender`, `Recipients`, `CC_Recipients`, `Subject`, `Body`, `SentDate`, `Status`) VALUES
(7, '[value-2]', ' hi amir ', '[value-4]', '[value-5]', '[value-6]', '2023-06-29', 'Not seen'),
(27, 'amirali', ' hi amir ', '[value-4]', '[value-5]', '[value-6]', '2023-07-01', 'Not seen'),
(28, 'amir21', 'amirseigal', '', 'a', 'a', '2023-07-01', 'Not seen');

--
-- Triggers `emails`
--
DELIMITER $$
CREATE TRIGGER `New_Email_Notification` AFTER INSERT ON `emails` FOR EACH ROW INSERT INTO notifications(UserName,Notification,NotificationDate)
SELECT Recipients,'You recieved a new email',NOW() FROM emails ORDER BY EmailID DESC LIMIT 1
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `Notification_For_Delete` AFTER DELETE ON `emails` FOR EACH ROW INSERT INTO notifications(UserName,Notification,NotificationDate)
SELECT UserName,'Your Email has been Deleted successfuly',NOW() FROM logins ORDER BY LoginDate DESC LIMIT 1
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `logins`
--

CREATE TABLE `logins` (
  `LoginID` int(11) NOT NULL,
  `UserName` varchar(30) NOT NULL,
  `LoginDate` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `NotificationID` int(11) NOT NULL,
  `UserName` varchar(30) NOT NULL,
  `Notification` varchar(512) NOT NULL,
  `NotificationDate` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`NotificationID`, `UserName`, `Notification`, `NotificationDate`) VALUES
(1, 'amirr', 'bruh', '2023-06-29'),
(2, 'amirr', 'You recieved a new email', '2023-06-29'),
(3, 'amirr', 'Wellcome to voovle', '2023-06-29'),
(4, 'amirseigal', 'Wellcome to voovle', '2023-06-29'),
(5, 'amirseigal', 'You recieved a new email', '2023-06-29'),
(6, 'amirseigal', 'You recieved a new email', '2023-06-29'),
(8, 'amirseigal', 'Your has been Deleted successfuly', '2023-06-29'),
(9, 'amirseigal', 'Your Email has been Deleted successfuly', '2023-06-29'),
(10, 'amirseigal', 'Your Email has been Deleted successfuly', '2023-06-29'),
(12, 'amirseigal', 'Your Profile has been Updated successfuly', '2023-06-29'),
(13, 'ardalan', 'Wellcome to voovle', '2023-06-29'),
(14, 'amirseigal', 'Your Email has been Deleted successfuly', '2023-06-29'),
(15, 'amirali', 'Wellcome to voovle', '2023-06-30'),
(16, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(17, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(18, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(19, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(20, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(21, 'amirali', 'Your Profile has been Updated successfuly', '2023-06-30'),
(23, 'amirali', 'Wellcome to voovle', '2023-07-01'),
(35, 'hi', 'Wellcome to voovle', '2023-07-01'),
(37, 'amirali', 'Your Email has been Deleted successfuly', '2023-07-01'),
(38, 'amirali', 'Your Profile has been Updated successfuly', '2023-07-01'),
(39, 'amirali', 'Your Profile has been Updated successfuly', '2023-07-01'),
(40, 'amirali', 'Your Profile has been Updated successfuly', '2023-07-01'),
(41, 'amirali', 'Your Profile has been Updated successfuly', '2023-07-01'),
(42, 'amirali', 'You recieved a new email', '2023-07-01'),
(43, 'amirali', 'You recieved a new email', '2023-07-01'),
(44, 'amirali', 'You recieved a new email', '2023-07-01'),
(73, 'amir21', 'Wellcome to voovle', '2023-07-01'),
(74, 'hi amir21', 'You recieved a new email', '2023-07-01'),
(75, 'amirseigal', 'You recieved a new email', '2023-07-01');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `UserID` int(11) NOT NULL,
  `UserName` varchar(30) NOT NULL,
  `Pass` varchar(66) NOT NULL,
  `FirstName` varchar(30) NOT NULL,
  `LastName` varchar(30) NOT NULL,
  `NickName` varchar(30) NOT NULL,
  `ID` varchar(10) NOT NULL,
  `Address` varchar(512) NOT NULL,
  `BirthDate` date NOT NULL,
  `PhoneNumber` varchar(13) NOT NULL,
  `CreationDate` date NOT NULL,
  `Status` varchar(7) NOT NULL DEFAULT 'Public'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`UserID`, `UserName`, `Pass`, `FirstName`, `LastName`, `NickName`, `ID`, `Address`, `BirthDate`, `PhoneNumber`, `CreationDate`, `Status`) VALUES
(2, 'amirseigal', '17fe2d8223e3bd8ee8ddea54b521ab073d796887', 'amirreza', 'seighali', 'amir', '2581456043', 'rasht shahrdari', '2002-09-03', '09117158818', '2023-06-29', 'Public'),
(6, 'amirali', '16884d3ddaef8bd2f0535cc09fb03532b96358bf', 'ali', 'amir', 'a', '2334', 'sari', '2009-02-01', '0911', '2023-07-01', 'Public'),
(7, 'hi', 'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d', 'a', 'a', 'a', 'a', 'a', '2001-01-01', '01', '2023-07-01', 'Public'),
(8, 'amir21', '1dd89e5367785ba89076cd264daac0464fdf0d7b', 'a', 'a', 'a', '1', 'a', '2001-01-01', '11', '2023-07-01', 'Public');

--
-- Triggers `users`
--
DELIMITER $$
CREATE TRIGGER `Update_Notification` AFTER UPDATE ON `users` FOR EACH ROW INSERT INTO notifications(UserName,Notification,NotificationDate)
SELECT UserName,'Your Profile has been Updated successfuly',NOW() FROM logins ORDER BY LoginDate DESC LIMIT 1
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `Wellcome_Notification` AFTER INSERT ON `users` FOR EACH ROW INSERT INTO notifications(UserName,Notification,NotificationDate)
SELECT UserName,'Wellcome to voovle',NOW() FROM users ORDER BY UserID DESC LIMIT 1
$$
DELIMITER ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `emails`
--
ALTER TABLE `emails`
  ADD PRIMARY KEY (`EmailID`);

--
-- Indexes for table `logins`
--
ALTER TABLE `logins`
  ADD PRIMARY KEY (`LoginID`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`NotificationID`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`UserID`,`UserName`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `emails`
--
ALTER TABLE `emails`
  MODIFY `EmailID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `logins`
--
ALTER TABLE `logins`
  MODIFY `LoginID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `NotificationID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=76;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `UserID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
