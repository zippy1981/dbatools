using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Sqlcollaborative.Dbatools.Utility
{
    [TestClass]
    public class DbaDateTimeBaseTest
    {
        [DataRow(2018,7,6)]
        [DataRow(1981,4,28)]
        [DataRow(1776,7,4)]
        [TestMethod]
        public void TestEquality(int year, int month, int day)
        {
            var dateTime = new DateTime(year, month, day);
            var dbaDateTime = new DbaDateTimeBase(dateTime);
            var dbaDateTime2 = new DbaDateTimeBase(dateTime);
            Assert.IsTrue(dbaDateTime == dateTime);
            Assert.IsTrue(dbaDateTime == dbaDateTime2);
            Assert.IsFalse(dbaDateTime != dateTime);
            Assert.IsFalse(dbaDateTime != dbaDateTime2);
            Assert.AreNotEqual(dateTime, dbaDateTime);
            Assert.AreEqual(dateTime, dbaDateTime.Date);
            Assert.AreEqual(dateTime, (DateTime)dbaDateTime);
            Assert.AreEqual(year, dbaDateTime.Year);
            Assert.AreEqual(month, dbaDateTime.Month);
            Assert.AreEqual(day, dbaDateTime.Day);
        }
    }
}