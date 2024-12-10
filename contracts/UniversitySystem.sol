// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract UserBase {
    enum Role { None, Admin, Teacher, Student }

    struct User {
        address userAddress;
        string name;
        Role role;
    }

    mapping(address => User) public users;


    modifier onlyAdmin() {
        require(users[msg.sender].role == Role.Admin, "Only admins can perform this action");
        _;
    }

    modifier onlyTeacher() {
        require(users[msg.sender].role == Role.Teacher, "Only teachers can perform this action");
        _;
    }

    modifier onlyStudent() {
        require(users[msg.sender].role == Role.Student, "Only students can perform this action");
        _;
    }
}

abstract contract CourseBase {
    struct ClassSession {
        uint date;
        mapping(address => bool) attendance;
        mapping(address => uint) grades;
    }

    struct Course {
        uint id;
        string name;
        string description;
        address teacher;
        mapping(address => bool) participants;
        mapping(address => bool) pendingStudents;
        ClassSession[] sessions;

        uint totalGrades;
        uint totalAttendance;
        uint sessionCount;
        uint participantCount;
    }

    Course[] public courses;

    // Счетчик ID курсов
    uint public nextCourseId;
}

abstract contract UserManager is UserBase {
    event UserAdded(address userAddress, string name, Role role);
    event UserRoleChanged(address userAddress, Role newRole);

    function _stringToRole(string memory _roleString) internal pure returns (Role) {
        if (keccak256(abi.encodePacked(_roleString)) == keccak256(abi.encodePacked("Admin"))) {
            return Role.Admin;
        }
        else if (keccak256(abi.encodePacked(_roleString)) == keccak256(abi.encodePacked("Teacher"))) {
            return Role.Teacher;
        }
        else if (keccak256(abi.encodePacked(_roleString)) == keccak256(abi.encodePacked("Student"))) {
            return Role.Student;
        }
        else {
            return Role.None; // Возвращаем None, если роль не распознана
        }
    }

    function addUserAdmin(address _userAddress, string memory _name, string memory _roleString) public onlyAdmin {
        Role newRole = _stringToRole(_roleString);
        require(newRole != Role.None, "Invalid role string");
        require(users[_userAddress].role == Role.None, "User already exists");

        users[_userAddress] = User(_userAddress, _name, newRole);
        emit UserAdded(_userAddress, _name, newRole);
    }

    function changeUserRoleAdmin(address _userAddress, string memory _newRoleString) public onlyAdmin {
        require(users[_userAddress].role != Role.None, "User does not exist");
        require(users[_userAddress].role != Role.Admin, "You can't change role for Admin");


        Role newRole = _stringToRole(_newRoleString);
        users[_userAddress].role = newRole;
        emit UserRoleChanged(_userAddress, newRole);
    }
}

abstract contract CourseManager is UserBase, CourseBase {
    event CourseCreated(uint courseId, string name, string description, address teacherAddress);
    event StudentAssignedToCourse(uint courseId, address userAddress);
    event StudentEnrolled(uint courseId, address studentAddress);
    event StudentConfirmed(uint courseId, address studentAddress);
    event CourseEdited(uint courseId, string newName, string newDescription);

    function createCourseAdmin(string memory _name, string memory _description, address _teacherAddress) public onlyAdmin {
        require(users[_teacherAddress].role == Role.Teacher, "Assigned address is not a teacher");

        Course storage newCourse = courses.push();
        newCourse.id = nextCourseId;
        newCourse.name = _name; 
        newCourse.description = _description;
        newCourse.teacher = _teacherAddress;

        emit CourseCreated(nextCourseId, _name, _description, _teacherAddress);
        nextCourseId += 1;
    }

    function assignStudentToCourseAdmin(uint _courseId, address _studentAddress) public onlyAdmin {
        require(_courseId < nextCourseId, "Invalid course ID");
        require(users[_studentAddress].role == Role.Student, "Only students can be assigned to courses");

        Course storage course = courses[_courseId];
        require(!course.participants[_studentAddress], "Student is already assigned to this course");

        course.participants[_studentAddress] = true;
        course.pendingStudents[_studentAddress] = false;
        // ^ вот тут, как я понял, Solidity сам поймет, что хранить в памяти дефолтное значение не надо
        // также можем так делать, т.к. если записи о студенте там нет, то оно и не будет создана по причине выше
        course.participantCount += 1;
        emit StudentAssignedToCourse(_courseId, _studentAddress);
    }

    function editCourseAdmin(uint _courseId, string memory _name, string memory _description) public onlyAdmin {
        require(_courseId < nextCourseId, "Course does not exist");
        Course storage course = courses[_courseId];
        course.name = _name;
        course.description = _description;
        emit CourseEdited(_courseId, _name, _description);
    }

    function editOwnCourseTeacher(uint _courseId, string memory _name, string memory _description) public onlyTeacher {
        require(_courseId < nextCourseId, "Course does not exist");
        Course storage course = courses[_courseId];
        require(course.teacher == msg.sender, "You are not the teacher of this course");
        course.name = _name;
        course.description = _description;
        emit CourseEdited(_courseId, _name, _description);
    }

    function confirmStudentTeacher(uint _courseId, address _studentAddress) public onlyTeacher {
        require(_courseId < nextCourseId, "Invalid course ID");
        Course storage course = courses[_courseId];
        require(course.teacher == msg.sender, "You are not the teacher of this course");

        require(course.pendingStudents[_studentAddress], "Student is not in the pending list");

        course.participants[_studentAddress] = true;
        course.pendingStudents[_studentAddress] = false;
        // ^ вот тут, как я понял, Solidity сам поймет, что хранить в памяти дефолтное значение не надо
        course.participantCount += 1;
        emit StudentConfirmed(_courseId, _studentAddress);
    }

    function getCoursesStudent() public view onlyStudent returns (uint[] memory) {
        uint count = 0;
        for (uint i = 0; i < courses.length; i++) {
            if (courses[i].participants[msg.sender]) {
                count++;
            }
        }

        uint[] memory studentCourses = new uint[](count);
        uint index = 0;
        for (uint i = 0; i < courses.length; i++) {
            if (courses[i].participants[msg.sender]) {
                studentCourses[index] = courses[i].id;
                index++;
            }
        }
        // хочу уточнить, лучше делать так ^ или через push в изначально пустой вектор

        return studentCourses;
    }

    function enrollInCourseStudent(uint _courseId) public onlyStudent {
        require(_courseId < nextCourseId, "Invalid course ID");

        Course storage course = courses[_courseId];
        require(!course.participants[msg.sender], "You have already assigned to this course");
        require(!course.pendingStudents[msg.sender], "You have already requested enrollment");

        course.pendingStudents[msg.sender] = true;
        emit StudentEnrolled(_courseId, msg.sender);
    }
}

abstract contract AttendanceAndGrades is UserBase, CourseBase {
    event ScheduleAdded(uint courseId, uint date);
    event AttendanceMarked(uint courseId, address student, uint date);
    event GradeAssigned(uint courseId, address student, uint grade, uint date);

    function addSessionTeacher(uint _courseId, uint _date) public onlyTeacher {
        require(_courseId < nextCourseId, "Course does not exist");
        Course storage course = courses[_courseId];
        require(course.teacher == msg.sender, "Only the course teacher can add to the schedule");
        ClassSession storage newSession = course.sessions.push();
        newSession.date = _date;
        course.sessionCount += 1;
        emit ScheduleAdded(_courseId, _date);
    }

    function markAttendanceTeacher(uint _courseId, address _studentAddress, uint _sessionIndex) public onlyTeacher {
        require(_courseId < nextCourseId, "Course does not exist");
        Course storage course = courses[_courseId];
        require(course.teacher == msg.sender, "You are not the teacher of this course");
        require(course.participants[_studentAddress], "Student is not enrolled in this course");
        require(_sessionIndex < course.sessions.length, "Invalid session index");
        require(!course.sessions[_sessionIndex].attendance[_studentAddress], "Already marked");
        
        course.sessions[_sessionIndex].attendance[_studentAddress] = true;
        course.totalAttendance += 1;
        emit AttendanceMarked(_courseId, _studentAddress, course.sessions[_sessionIndex].date);
    }

    function assignGradeTeacher(uint _courseId, address _studentAddress, uint _grade, uint _sessionIndex) public onlyTeacher {
        require(_courseId < nextCourseId, "Course does not exist");
        Course storage course = courses[_courseId];
        require(course.teacher == msg.sender, "Only the course teacher can assign grades");
        require(course.participants[_studentAddress], "Student is not enrolled in this course");
        require(_sessionIndex < course.sessions.length, "Invalid session index");

        // При замене ненулевой оценки не забываем вычесть из totalGrades прошлую оценку
        course.totalGrades += _grade - course.sessions[_sessionIndex].grades[_studentAddress];
        course.sessions[_sessionIndex].grades[_studentAddress] = _grade;
        emit GradeAssigned(_courseId, _studentAddress, _grade, course.sessions[_sessionIndex].date);
    }

    function getAttendanceStudent(uint _courseId) public view onlyStudent returns (uint[] memory) {
        require(users[msg.sender].role == Role.Student, "Only students can access their attendance");
        
        uint[] memory attendanceDates = new uint[](courses[_courseId].sessions.length);
        
        for (uint i = 0; i < courses[_courseId].sessions.length; i++) {
            if (courses[_courseId].sessions[i].attendance[msg.sender]) {
                attendanceDates[i] = courses[_courseId].sessions[i].date;
            }
        }
        return attendanceDates;
    }

    function getStudentAttendanceTeacherOrAdmin(uint _courseId, address _studentAddress) public view returns (uint[] memory) {
        require(
            users[msg.sender].role == Role.Admin || 
            (users[msg.sender].role == Role.Teacher && courses[_courseId].teacher == msg.sender),
            "You do not have access to this student's attendance"
        );

        uint[] memory studentAttendance = new uint[](courses[_courseId].sessions.length);
        
        for (uint i = 0; i < courses[_courseId].sessions.length; i++) {
            if (courses[_courseId].sessions[i].attendance[_studentAddress]) {
                studentAttendance[i] = courses[_courseId].sessions[i].date;
            }
        }

        return studentAttendance;
    }

    function getStudentGradesTeacherOrAdmin(uint _courseId, address _studentAddress) public view returns (uint[] memory) {
        require(
            users[msg.sender].role == Role.Admin || 
            (users[msg.sender].role == Role.Teacher && courses[_courseId].teacher == msg.sender),
            "You do not have access to this student's grades"
        );

        uint[] memory studentGrades = new uint[](courses[_courseId].sessions.length);
        
        for (uint i = 0; i < courses[_courseId].sessions.length; i++) {
            studentGrades[i] = courses[_courseId].sessions[i].grades[_studentAddress];
        }

        return studentGrades;
    }
}

abstract contract ReportsManager is UserBase, CourseBase {
    function _getSessionRangeByDateRange(uint _courseId, uint _startDate, uint _endDate) 
            internal view returns (uint startIndex, uint count) {
        require(_startDate <= _endDate, "Invalid date range");
        require(_courseId < courses.length, "Course does not exist");

        Course storage course = courses[_courseId];

        startIndex = 0;
        while (startIndex < course.sessions.length && course.sessions[startIndex].date < _startDate) {
            startIndex++;
        }

        count = 0;
        uint endIndex = startIndex;
        while (endIndex < course.sessions.length && course.sessions[endIndex].date <= _endDate) {
            count++;
            endIndex++;
        }

        return (startIndex, count);
    }

    function viewSchedule(uint _courseId, address _student, uint _startDate, uint _endDate) 
        external view returns (uint[] memory) {
        require(
            users[msg.sender].role == Role.Admin || 
            users[msg.sender].role == Role.Teacher || 
            (users[msg.sender].role == Role.Student && msg.sender == _student),
            "Access denied"
        );
        require(courses[_courseId].participants[_student], "Student not enrolled in course");

        (uint startIndex, uint count) = _getSessionRangeByDateRange(_courseId, _startDate, _endDate);

        uint[] memory sessionDates = new uint[](count);
        Course storage course = courses[_courseId];

        for (uint i = 0; i < count; i++) {
            sessionDates[i] = course.sessions[startIndex + i].date;
        }

        return sessionDates;
    }

    function viewGrades(uint _courseId, address _student, uint _startDate, uint _endDate)
            external view returns (uint[] memory) {
        require(
            users[msg.sender].role == Role.Admin || 
            users[msg.sender].role == Role.Teacher || 
            (users[msg.sender].role == Role.Student && msg.sender == _student),
            "Access denied"
        );

        require(courses[_courseId].participants[_student], "Student not enrolled in course");

        (uint startIndex, uint count) = _getSessionRangeByDateRange(_courseId, _startDate, _endDate);

        uint[] memory grades = new uint[](count);
        Course storage course = courses[_courseId];

        for (uint i = 0; i < count; i++) {
            grades[i] = course.sessions[startIndex + i].grades[_student];
        }

        return grades;
    }

    function viewCourseStatistics(uint _courseId) external view returns (uint averageGrade, uint attendanceRate) {
        require(_courseId < courses.length, "Course does not exist");
        Course storage course = courses[_courseId];

        require(course.sessionCount > 0, "No sessions on this course");
        require(course.participantCount > 0, "No participant on this course");

        uint avgGrade = (course.totalGrades) / (course.sessionCount * course.participantCount);
        uint atdRate = (course.totalAttendance * 100) / (course.sessionCount * course.participantCount);

        return (avgGrade, atdRate);
    }
}

contract UniversitySystem is UserManager, CourseManager, AttendanceAndGrades, ReportsManager {
    constructor() {
        users[msg.sender] = User(msg.sender, "SuperAdmin", Role.Admin);
    }
}
