use blinova1;

CREATE TABLE CompanyStructure (
    EmployeeID INT PRIMARY KEY IDENTITY(1,1),
    FullName NVARCHAR(100) NOT NULL,
    Position NVARCHAR(50),
    Node HIERARCHYID NOT NULL
);

CREATE OR ALTER PROCEDURE ShowSubordinates
    @ManagerID INT
AS
BEGIN
    DECLARE @ManagerNode HIERARCHYID = (SELECT Node FROM CompanyStructure WHERE EmployeeID = @ManagerID);
    SELECT 
        Node.ToString() AS [���������� ����],
        Node.GetLevel() AS [�������],
        FullName AS [���], 
        Position AS [���������]
    FROM CompanyStructure
    WHERE Node.IsDescendantOf(@ManagerNode) = 1
    ORDER BY Node;
END;

CREATE OR ALTER PROCEDURE AddEmployee
    @ParentID INT,
    @Name NVARCHAR(100),
    @Pos NVARCHAR(50)
AS
BEGIN
    DECLARE @ParentNode HIERARCHYID, @LastChild HIERARCHYID;

    SELECT @ParentNode = Node FROM CompanyStructure WHERE EmployeeID = @ParentID;
    SELECT @LastChild = MAX(Node) 
    FROM CompanyStructure 
    WHERE Node.GetAncestor(1) = @ParentNode;

    INSERT INTO CompanyStructure (FullName, Position, Node)
    VALUES (@Name, @Pos, @ParentNode.GetDescendant(@LastChild, NULL));
END;

CREATE OR ALTER PROCEDURE MoveTeam
    @OldManagerID INT,
    @NewManagerID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @OldParent HIERARCHYID = (SELECT Node FROM CompanyStructure WHERE EmployeeID = @OldManagerID);
    DECLARE @NewParent HIERARCHYID = (SELECT Node FROM CompanyStructure WHERE EmployeeID = @NewManagerID); 

    IF @OldParent.IsDescendantOf(@NewParent) = 1
    BEGIN
        RAISERROR('������ ����������� ������������ � ��� ������������ ������������', 16, 1);
        RETURN;
    END
    DECLARE @LastChild HIERARCHYID = (SELECT MAX(Node) FROM CompanyStructure WHERE Node.GetAncestor(1) = @NewParent);
    DECLARE @NewRoot HIERARCHYID = @NewParent.GetDescendant(@LastChild, NULL);
    UPDATE CompanyStructure
    SET Node = Node.GetReparentedValue(@OldParent, @NewRoot)
    WHERE Node.IsDescendantOf(@OldParent) = 1 
      AND Node <> @OldParent;
END;



INSERT INTO CompanyStructure (FullName, Position, Node)
VALUES ('����� �������', '����������� ��������', hierarchyid::GetRoot());
EXEC AddEmployee @ParentID = 1, @Name = '����������� �����. ��������', @Pos = '����������� ��������';
EXEC AddEmployee @ParentID = 1, @Name = '������� ��. ��������', @Pos = '������������ ��������';
EXEC AddEmployee @ParentID = 2, @Name = '�������� �������', @Pos = '������� �������';
EXEC AddEmployee @ParentID = 4, @Name = '�������� �����������', @Pos = '������� �������';
EXEC AddEmployee @ParentID = 2, @Name = '����������� ���', @Pos = '���������� �� ���';
EXEC AddEmployee @ParentID = 3, @Name = '�������� ���.���.��.', @Pos = '������������ ����������� ������';
EXEC AddEmployee @ParentID = 6, @Name = '�������� ���.���.��.����', @Pos = '������������ ����������� ������';
EXEC AddEmployee @ParentID = 3, @Name = '������� ������� �2', @Pos = '������ �������';
EXEC ShowSubordinates @ManagerID = 1;
EXEC MoveTeam @OldManagerID = 2, @NewManagerID = 3;


DROP PROCEDURE IF EXISTS MoveTeam;
DROP PROCEDURE IF EXISTS AddEmployee;
DROP PROCEDURE IF EXISTS ShowSubordinates;
DROP TABLE IF EXISTS CompanyStructure;