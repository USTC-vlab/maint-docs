# 统一身份认证资料

## 响应样例

注：非原始响应，已解析为 Python `dict`：

```python
{
    'xbm': '1',
    'logintime': '2020-02-30 12:34:56',
    'gid': '2201234567',
    'ryzxztdm': '10',
    'ryfldm': '201030000',
    'loginip': '192.0.2.0',
    'name': '张三',
    'login': 'PB17000001',
    'zjhm': 'PB17000001',
    'glzjh': 'SA21011000\tPB17000001',
    'deptCode': '011',
    'email': 'noreply@mail.ustc.edu.cn'
}
```

??? example "原始响应内容（XML example）"

    ```xml
    <cas:serviceResponse xmlns:cas='http://www.yale.edu/tp/cas'>
    <cas:authenticationSuccess>
    <cas:user>SA21011000</cas:user>
    <attributes>
    <cas:xbm>1</cas:xbm>
    <cas:logintime>2020-02-30 12:34:56</cas:logintime>
    <cas:gid>2201234567</cas:gid>
    <cas:ryzxztdm>10</cas:ryzxztdm>
    <cas:ryfldm>201030000</cas:ryfldm>
    <cas:loginip>192.0.2.0</cas:loginip>
    <cas:name>张三</cas:name>
    <cas:login>SA21011000</cas:login>
    <cas:zjhm>SA21011000</cas:zjhm>
    <cas:glzjh>SA21011000	PB17000001</cas:glzjh>
    <cas:deptCode>011</cas:deptCode>
    <cas:email>noreply@mail.ustc.edu.cn</cas:email>
    </attributes>
    </cas:authenticationSuccess>
    </cas:serviceResponse>
    ```

!!! warning "`glzjh` 的值不完全可靠"

    根据 USTCCAS 的文档，这个属性中包含了用户所有的历史证件号（学号/工号），以 `\t` 分割。

    但是在实际操作中发现这个属性问题比较多，例如（以下例子经过匿名化处理）：

    1. 有教师的 glzjh 值为 `"BA01000000\t00000\tSA97000000"`，第一个值是二十多年前的博士 ID，而最新的教师证件号是中间的值
    2. 有 SA 新生的 glzjh 值为 `"U0000000"`
    3. 有 SA 新生的 glzjh 值为 `"null"`

## 人员在校状态码

```csv
id,sfztm,sfzt
1,10,在校
2,20,离校（含校内身份结束）
3,30,校内身份转换
5,40,离退休
6,50,"暂时离校(休学/出国等)"
7,99,其他
8,91,证件停用或注销
```

## 人员分类码

```csv
id,ryflm,ryfl
1,101010000,教工-正式编制教学岗
2,101020000,教工-正式编制科研岗
3,101030000,教工-正式编制管理岗
4,101040000,教工-正式编制支撑岗
5,101ZZ0000,教工-正式编制其他岗或未明岗
6,201010000,学生-正式科学学位博士
7,201020000,学生-正式科学学位硕士
8,201030000,学生-正式本科
9,201040000,学生-正式学生专科
10,201ZZ0000,学生-正式学生其他或未知层次
11,202010000,学生-专业学位博士
12,202020000,学生-专业学位硕士
13,202ZZ0000,学生-专业学位其他或未知层次
14,240030000,学生-夜大函授培训班本科
15,240040000,学生-夜大函数培训班专科
16,240ZZ0000,学生-夜大函数培训班其他或未知层次
17,290ZZ0000,短期培训学生
18,2ZZZZ0000,学生-其他类型学生
19,300000000,博士后
20,901000000,来访人员-上级部门各种类型来访人员
21,902000000,交流访问进修人员
22,903000000,来访人员-邀请来的讲座、演出、交流人员
23,904000000,来访人员-参加会议人员
24,905000000,来访人员-来校参观人员
25,906000000,来访人员-学生家长
26,9ZZ000000,来访人员-其他来访人员
27,Z01000000,教工家属
28,Z02000000,附中学生
29,ZZZ000000,其他人员
30,103ZZ0000,教工-校聘用人员其他岗或未明岗
31,180ZZ0000,各单位自聘人员
33,190ZZ0000,各单位临时聘用人员
34,301000000,校内博士后
35,309000000,企业博士后
```
