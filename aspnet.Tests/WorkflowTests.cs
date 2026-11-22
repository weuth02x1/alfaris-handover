using Alfaris.Handover.Data;
using Alfaris.Handover.Models;
using Xunit;

namespace Alfaris.Handover.Tests;

public class WorkflowTests
{
    [Fact]
    public void HrStartsClearanceThenEmployeeSubmitsAndRecipientAccepts()
    {
        var store = new HandoverStore();
        var hr = store.Person("30115")!;
        var employee = store.Person("10518")!;
        var recipient = store.Person("10524")!;
        var manager = store.Person("10501")!;

        var id = store.InitiateClearance(hr, "ANN-2026-0412");
        store.SaveForm(employee, id, "غطي المشاريع المفتوحة",
        [
            new HandoverTask { Title = "تسليم نظام الرواتب", Details = "المفاتيح والصلاحيات", AssigneeId = recipient.Id }
        ], true);

        var pending = store.Handover(id)!;
        Assert.Equal("pending_acceptance", pending.Status);
        store.AcceptTask(recipient, id, pending.Tasks[0].Id, "تم");
        Assert.Equal("pending_manager", store.Handover(id)!.Status);

        store.ManagerDecision(manager, id, true, "");
        Assert.Equal("pending_hr", store.Handover(id)!.Status);

        store.HrDecision(hr, id, true, "معتمد");
        var done = store.Handover(id)!;
        Assert.Equal("approved", done.Status);
        Assert.False(string.IsNullOrWhiteSpace(done.DocumentHash));
    }

    [Fact]
    public void SaveFormAcceptsNewTaskWithEmptyId()
    {
        var store = new HandoverStore();
        var hr = store.Person("30115")!;
        var employee = store.Person("10518")!;
        var recipient = store.Person("10524")!;
        var id = store.InitiateClearance(hr, "ANN-2026-0412");
        store.SaveForm(employee, id, "",
        [
            new HandoverTask { Id = "", Title = "task", Details = "d", AssigneeId = recipient.Id }
        ], true);
        Assert.Equal("pending_acceptance", store.Handover(id)!.Status);
        Assert.False(string.IsNullOrEmpty(store.Handover(id)!.Tasks[0].Id));
    }

    [Fact]
    public void LocalOtpMatchesThenExpires()
    {
        var box = new Alfaris.Handover.Services.OtpBox();
        box.Remember("a@b.co", "abc", DateTimeOffset.UtcNow.AddMinutes(5));
        Assert.True(box.Match("a@b.co", "abc"));
        Assert.False(box.Match("a@b.co", "abc"));
        box.Remember("a@b.co", "xyz", DateTimeOffset.UtcNow.AddMinutes(-1));
        Assert.Throws<WorkflowException>(() => box.Match("a@b.co", "xyz"));
    }

    [Fact]
    public void EmployeeCannotStartClearance()
    {
        var store = new HandoverStore();
        var employee = store.Person("10518")!;
        Assert.Throws<WorkflowException>(() => store.InitiateClearance(employee, "ANN-2026-0412"));
    }
}
