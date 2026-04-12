import { useState } from 'react';
import { Calendar, Lightbulb, TrendingUp, ArrowRight } from 'lucide-react';
import { PieChart, Pie, Cell, LineChart, Line, ResponsiveContainer } from 'recharts';
import Header from './Header';

const pieData = [
  { name: '软件开发', value: 42, color: '#A8E6CF' },
  { name: '市场营销', value: 42, color: '#FDD1B4' },
  { name: '办公租赁', value: 8, color: '#DCDE8D' },
  { name: '其他杂项', value: 8, color: '#C9CB7D' },
];

const lineData = [
  { name: '5月', value: 30 },
  { name: '6月', value: 35 },
  { name: '7月', value: 45 },
  { name: '8月', value: 55 },
  { name: '9月', value: 65 },
  { name: '10月', value: 70 },
];

export default function Analytics({ navigate }: any) {
  const [trendTab, setTrendTab] = useState('month');

  return (
    <div className="p-6 pt-12">
      {/* Header */}
      <Header title="财务统计" showLogo={true} />

      {/* Date Selector */}
      <div className="flex flex-col items-center mb-8">
        <p className="text-gray-600 text-sm font-medium mb-2">本月财务概览与分析报告</p>
        <button className="bg-[#F3F3F3] px-6 py-2.5 rounded-full flex items-center gap-2 text-sm font-bold text-gray-700">
          2023年10月 <Calendar size={16} />
        </button>
      </div>

      {/* Donut Chart */}
      <div className="bg-white rounded-[48px] p-8 mb-6 shadow-sm">
        <h3 className="text-xl font-extrabold text-[#1A1C1C] mb-4">项目占比</h3>
        <div className="relative h-64 flex items-center justify-center">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={[{ value: 100 }]}
                cx="50%"
                cy="50%"
                innerRadius={80}
                outerRadius={100}
                fill="#F3F4F6"
                stroke="none"
                isAnimationActive={false}
              />
              <Pie
                data={pieData}
                cx="50%"
                cy="50%"
                innerRadius={80}
                outerRadius={100}
                stroke="none"
                dataKey="value"
              >
                {pieData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <span className="text-3xl font-extrabold text-[#1A1C1C]">¥12,840</span>
            <span className="text-xs font-bold text-gray-500 mt-1">总支出</span>
          </div>
        </div>
        <div className="flex flex-col gap-4 mt-6 px-2">
          {[...pieData].sort((a, b) => b.value - a.value).map((item, i) => (
            <div key={i} className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-3.5 h-3.5 rounded-full" style={{ backgroundColor: item.color }}></div>
                <span className="text-[15px] font-medium text-gray-700">{item.name}</span>
              </div>
              <span className="text-[15px] font-bold text-[#1A1C1C]">{item.value}%</span>
            </div>
          ))}
        </div>
      </div>

      {/* Line Chart */}
      <div className="bg-white rounded-[48px] p-8 mb-6 shadow-sm">
        <div className="flex justify-between items-center mb-8">
          <h3 className="text-xl font-extrabold text-[#1A1C1C]">项目趋势</h3>
          <div className="flex bg-[#A8E6CF]/30 rounded-full p-1">
            <button 
              onClick={() => setTrendTab('day')}
              className={`px-4 py-1.5 text-xs font-bold rounded-full transition-colors ${trendTab === 'day' ? 'text-[#2C6956] bg-white shadow-sm' : 'text-gray-600'}`}
            >日</button>
            <button 
              onClick={() => setTrendTab('month')}
              className={`px-4 py-1.5 text-xs font-bold rounded-full transition-colors ${trendTab === 'month' ? 'text-[#2C6956] bg-white shadow-sm' : 'text-gray-600'}`}
            >月</button>
            <button 
              onClick={() => setTrendTab('year')}
              className={`px-4 py-1.5 text-xs font-bold rounded-full transition-colors ${trendTab === 'year' ? 'text-[#2C6956] bg-white shadow-sm' : 'text-gray-600'}`}
            >年</button>
          </div>
        </div>
        <div className="h-40">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={lineData}>
              <Line 
                type="monotone" 
                dataKey="value" 
                stroke="#A8E6CF" 
                strokeWidth={4} 
                dot={{ r: 4, fill: "#2C6956", strokeWidth: 0 }} 
                activeDot={{ r: 6 }} 
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="flex justify-between mt-2 px-2">
          {lineData.map((item, i) => (
            <span key={i} className="text-[11px] font-bold text-gray-500">{item.name}</span>
          ))}
        </div>
      </div>

      {/* Budget Health */}
      <div className="bg-[#F3F3F3] rounded-[48px] p-8 mb-6">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-xl font-extrabold text-[#1A1C1C]">预算健康度</h3>
          <span className="text-sm font-bold text-[#2C6956]">总预算: ¥25,000</span>
        </div>
        
        <div className="space-y-6">
          <BudgetBar 
            title="办公租赁" 
            amount="¥4,500 / ¥5,000 (90%)" 
            progress={90} 
            color="bg-[#A8E6CF]" 
          />
          <BudgetBar 
            title="市场营销" 
            amount="¥6,200 / ¥5,500 (112%)" 
            progress={100} 
            color="bg-[#BA1A1A]" 
            amountColor="text-[#BA1A1A]"
          />
          <BudgetBar 
            title="员工薪酬" 
            amount="¥8,000 / ¥10,000 (80%)" 
            progress={80} 
            color="bg-[#DCDE8D]" 
          />
        </div>
      </div>

      {/* Smart Insights */}
      <div>
        <h3 className="text-xl font-extrabold text-[#1A1C1C] mb-4">智能洞察</h3>
        
        <div className="bg-[#B1EFD8] rounded-[32px] p-6 mb-4 shadow-sm">
          <div className="flex items-center gap-2 mb-3">
            <Lightbulb size={20} className="text-[#002118]" />
            <h4 className="text-base font-bold text-[#002118]">节省方案</h4>
          </div>
          <p className="text-sm text-[#002118] font-medium leading-relaxed">
            您的“市场营销”支出已连续三个月超出预算。建议整合投放渠道以降低15%的固定成本。
          </p>
        </div>

        <div className="bg-[#FFDCC5] rounded-[32px] p-6 mb-4 shadow-sm">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp size={20} className="text-[#2C1605]" />
            <h4 className="text-base font-bold text-[#2C1605]">健康提醒</h4>
          </div>
          <p className="text-sm text-[#2C1605] font-medium leading-relaxed">
            本月结余相比上月增长了12%。这是一个积极的信号，可以考虑将部分资金投入研发。
          </p>
        </div>

        <div className="bg-[#2C6956] rounded-[32px] p-8 text-white relative overflow-hidden">
          <div className="absolute right-0 bottom-0 w-32 h-32 bg-white/10 rounded-tl-full blur-2xl"></div>
          <h2 className="text-2xl font-extrabold mb-6 leading-tight relative z-10">
            优化财务结构，<br/>让增长更自然。
          </h2>
          <button className="bg-[#A8E6CF] text-[#2C6957] px-6 py-3 rounded-full font-extrabold flex items-center gap-2 relative z-10">
            立即生成深度报告 <ArrowRight size={18} />
          </button>
        </div>
      </div>
    </div>
  );
}

function BudgetBar({ title, amount, progress, color, amountColor = "text-gray-600" }: any) {
  return (
    <div>
      <div className="flex justify-between items-center mb-2">
        <span className="text-sm font-bold text-[#1A1C1C]">{title}</span>
        <span className={`text-sm font-bold ${amountColor}`}>{amount}</span>
      </div>
      <div className="h-4 bg-[#E2E2E2] rounded-full overflow-hidden">
        <div className={`h-full rounded-full ${color}`} style={{ width: `${progress}%` }}></div>
      </div>
    </div>
  );
}
