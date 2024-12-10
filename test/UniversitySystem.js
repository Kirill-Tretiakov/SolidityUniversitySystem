const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniversitySystem", function () {
    let universitySystem;
    let owner;
    let user1;
    let user2;
    let user3;

    beforeEach(async function () {
        [owner, user1, user2, user3] = await ethers.getSigners();

        const UniversitySystem = await ethers.getContractFactory("UniversitySystem");
        universitySystem = await UniversitySystem.deploy();
    });

    describe("User Management", function () {
        it("Should deploy the contract and set the admin role correctly", async function () {
            const user = await universitySystem.users(owner.address);
            expect(user.role).to.equal(1);
            expect(user.name).to.equal("SuperAdmin");
        });

        it("Should allow the admin to add a user with a valid role", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            const user = await universitySystem.users(user1.address);
            expect(user.role).to.equal(2);
            expect(user.name).to.equal("TeacherUser");
        });

        it("Should revert when adding a user with an invalid role", async function () {
            await expect(
                universitySystem.connect(owner).addUserAdmin(user1.address, "InvalidUser", "InvalidRole")
            ).to.be.revertedWith("Invalid role string");
        });

        it("Should revert when adding a user that already exists", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await expect(
                universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher")
            ).to.be.revertedWith("User already exists");
        });

        it("Should allow the admin to change the role of an existing user", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).changeUserRoleAdmin(user1.address, "Student");
            const user = await universitySystem.users(user1.address);
            expect(user.role).to.equal(3);
        });

        it("Should revert when changing the role of a non-existent user", async function () {
            await expect(
                universitySystem.connect(owner).changeUserRoleAdmin(user1.address, "Student")
            ).to.be.revertedWith("User does not exist");
        });

        it("Should revert when attempting to change the role of an admin", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "AdminUser", "Admin");
            await expect(
                universitySystem.connect(owner).changeUserRoleAdmin(user1.address, "Teacher")
            ).to.be.revertedWith("You can't change role for Admin");
        });

        it("Should allow an admin to create a course with a valid teacher", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            const course = await universitySystem.courses(0);
            expect(course.name).to.equal("Course1");
            expect(course.description).to.equal("Description1");
            expect(course.teacher).to.equal(user1.address);
        });

        it("Should revert when creating a course with an invalid teacher", async function () {
            await expect(
                universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address)
            ).to.be.revertedWith("Assigned address is not a teacher");
        });

        it("Should revert when assigning a student who is already assigned to the course", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);
            await expect(
                universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address)
            ).to.be.revertedWith("Student is already assigned to this course");
        });

        it("Should allow an admin to edit a course", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(owner).editCourseAdmin(0, "NewCourseName", "NewDescription");
            const course = await universitySystem.courses(0);
            expect(course.name).to.equal("NewCourseName");
            expect(course.description).to.equal("NewDescription");
        });

        it("Should allow a teacher to edit their own course", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user1).editOwnCourseTeacher(0, "UpdatedName", "UpdatedDescription");
            const course = await universitySystem.courses(0);
            expect(course.name).to.equal("UpdatedName");
            expect(course.description).to.equal("UpdatedDescription");
        });

        it("Should revert when a teacher tries to edit a course they don't teach", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "TeacherUser2", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await expect(
                universitySystem.connect(user2).editOwnCourseTeacher(0, "UpdatedName", "UpdatedDescription")
            ).to.be.revertedWith("You are not the teacher of this course");
        });

        it("Should revert when confirming a student not in the pending list", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await expect(
                universitySystem.connect(user1).confirmStudentTeacher(0, user2.address)
            ).to.be.revertedWith("Student is not in the pending list");
        });

        it("Should revert when a student tries to enroll in a course they are already enrolled in", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user2).enrollInCourseStudent(0);
            await universitySystem.connect(user1).confirmStudentTeacher(0, user2.address);
            await expect(
                universitySystem.connect(user2).enrollInCourseStudent(0)
            ).to.be.revertedWith("You have already assigned to this course");
        });

        it("Should revert when a non-teacher tries to add a session", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);

            await expect(
                universitySystem.connect(owner).addSessionTeacher(0, 20240101)
            ).to.be.revertedWith("Only teachers can perform this action");
        });

        it("Should revert when marking attendance for a non-enrolled student", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);

            await expect(
                universitySystem.connect(user1).markAttendanceTeacher(0, user2.address, 0)
            ).to.be.revertedWith("Student is not enrolled in this course");
        });

        it("Should allow a student to view their attendance", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);
            await universitySystem.connect(user1).markAttendanceTeacher(0, user2.address, 0);

            const attendance = await universitySystem.connect(user2).getAttendanceStudent(0);
            expect(attendance).to.deep.equal([20240101]);
        });

        it("Should allow a teacher or admin to view a student's grades", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);
            await universitySystem.connect(user1).assignGradeTeacher(0, user2.address, 95, 0);

            const grades = await universitySystem.connect(user1).getStudentGradesTeacherOrAdmin(0, user2.address);
            expect(grades).to.deep.equal([95]);
        });

        it("Should return session dates within a date range for a student", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);

            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240115);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240201);

            const schedule = await universitySystem.viewSchedule(0, user2.address, 20240101, 20240131);
            expect(schedule).to.deep.equal([20240101, 20240115]);
        });

        it("Should return grades within a date range for a student", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);

            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240115);
            await universitySystem.connect(user1).assignGradeTeacher(0, user2.address, 90, 0);
            await universitySystem.connect(user1).assignGradeTeacher(0, user2.address, 85, 1);

            const grades = await universitySystem.viewGrades(0, user2.address, 20240101, 20240131);
            expect(grades).to.deep.equal([90, 85]);
        });

        it("Should calculate average grade and attendance rate for a course", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).addUserAdmin(user2.address, "StudentUser", "Student");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(owner).assignStudentToCourseAdmin(0, user2.address);

            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240115);
            await universitySystem.connect(user1).assignGradeTeacher(0, user2.address, 90, 0);
            await universitySystem.connect(user1).assignGradeTeacher(0, user2.address, 85, 1);
            await universitySystem.connect(user1).markAttendanceTeacher(0, user2.address, 0);
            await universitySystem.connect(user1).markAttendanceTeacher(0, user2.address, 1);

            const [averageGrade, attendanceRate] = await universitySystem.viewCourseStatistics(0);
            expect(averageGrade).to.equal(87);
            expect(attendanceRate).to.equal(100);
        });

        it("Should revert if course has no sessions in viewCourseStatistics", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);

            await expect(
                universitySystem.viewCourseStatistics(0)
            ).to.be.revertedWith("No sessions on this course");
        });

        it("Should revert if course has no participants in viewCourseStatistics", async function () {
            await universitySystem.connect(owner).addUserAdmin(user1.address, "TeacherUser", "Teacher");
            await universitySystem.connect(owner).createCourseAdmin("Course1", "Description1", user1.address);
            await universitySystem.connect(user1).addSessionTeacher(0, 20240101);

            await expect(
                universitySystem.viewCourseStatistics(0)
            ).to.be.revertedWith("No participant on this course");
        });
    });
});
